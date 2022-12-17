//
//  SprintAccount.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

struct SprintAccount: CustomStringConvertible, CustomDebugStringConvertible
{
    let sprintID: Int
    let startTime: Date?
    let endTime: Date?
    let name: String?   // e.g. 'Sprint 23'
    let goal: String?   // e.g. 'Enhance customer experience on Guest Invite checkout'
    
    let committedUserStories: [Ticket]
    let committedTasks: [Ticket]
    let committedBugs: [Ticket]
    
    let insertedUserStories: [Ticket]
    let insertedTasks: [Ticket]
    let insertedBugs: [Ticket]
    
    init(sprintID: Int,
        startTime: Date?,
         endTime: Date?,
         name: String?,
         goal: String?,
         committedUserStories: [Ticket],
         committedTasks: [Ticket],
         committedBugs: [Ticket],
         insertedUserStories: [Ticket],
         insertedTasks: [Ticket],
         insertedBugs: [Ticket])
    {
        self.sprintID = sprintID
        self.startTime = startTime
        self.endTime = endTime
        self.name = name
        self.goal = goal
        self.committedUserStories = committedUserStories
        self.committedTasks = committedTasks
        self.committedBugs = committedBugs
        self.insertedUserStories = insertedUserStories
        self.insertedTasks = insertedTasks
        self.insertedBugs = insertedBugs
        
        timespentOnBugsFromCommitment = committedBugs.reduce(0)
        {
            switch $1.ticketType
            {
            case .bug(let timeSpent):
                return $0 + (timeSpent ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        timespentOnBugsFromInsertions = insertedBugs.reduce(0)
        {
            switch $1.ticketType
            {
            case .bug(let timeSpent):
                return $0 + (timeSpent ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        
        timespentOnTasksFromCommitment = committedTasks.reduce(0)
        {
            switch $1.ticketType
            {
            case .task(let timeSpent):
                return $0 + (timeSpent ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        
        timespentOnTasksFromInsertions = insertedTasks.reduce(0)
        {
            switch $1.ticketType
            {
            case .task(let timeSpent):
                return $0 + (timeSpent ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        
        committedStorypoints = committedUserStories.reduce(0)
        {
            switch $1.ticketType
            {
            case .userStory(let storyPoints): return $0 + (storyPoints ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        
        insertedStorypoints = insertedUserStories.reduce(0)
        {
            switch $1.ticketType
            {
            case .userStory(let storyPoints): return $0 + (storyPoints ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        totalStorypoints = committedStorypoints + insertedStorypoints
        
        totalTimeSpentOnBugs = timespentOnBugsFromCommitment + timespentOnBugsFromInsertions
        totalTimeSpentOnTasks = timespentOnTasksFromCommitment + timespentOnTasksFromInsertions
        
        storiesDoneFromCommitment = committedUserStories.reduce(0) { $0 + ($1.status == .done ? 1 : 0) }
        storiesDoneFromInsertions = insertedUserStories.reduce(0) { $0 + ($1.status == .done ? 1 : 0) }
        
        tasksDoneFromCommitment = committedTasks.reduce(0) { $0 + ($1.status == .done ? 1 : 0) }
        tasksDoneFromInsertions = insertedTasks.reduce(0) { $0 + ($1.status == .done ? 1 : 0) }
        
        bugsDoneFromCommitment = committedBugs.reduce(0) { $0 + ($1.status == .done ? 1 : 0) }
        bugsDoneFromInsertions = insertedBugs.reduce(0) { $0 + ($1.status == .done ? 1 : 0) }
        
        storypointsFromCommitmentDone = committedUserStories.reduce(0)
        {
            if $1.status != .done { return $0 }
            
            switch $1.ticketType
            {
            case .userStory(let storyPoints): return $0 + (storyPoints ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        storypointsFromInsertionsDone = insertedUserStories.reduce(0)
        {
            if $1.status != .done { return $0 }
            
            switch $1.ticketType
            {
            case .userStory(let storyPoints): return $0 + (storyPoints ?? 0)
            default: fatalError("Incorrect ticket type in array")
            }
        }
        
        
        storiesWithoutStorypointsFromCommitment = committedUserStories.filter
        {
            switch $0.ticketType
            {
            case .userStory(let storyPoints): return nil == storyPoints
            default: fatalError("Incorrect type of userstory in array")
            }

        }

        storiesWithoutStorypointsFromInsertions = insertedUserStories.filter
        {
            switch $0.ticketType
            {
            case .userStory(let storyPoints): return nil == storyPoints
            default: fatalError("Incorrect type of userstory in array")
            }
        }
                
        tasksDoneFromCommitmentWithoutTimespent = committedTasks.reduce(into: [Ticket]())
        {
            if $1.status != .done { return }
            switch $1.ticketType
            {
            case .task(let timespent): if 0 == timespent { $0.append($1) }
            default: fatalError("Incorrect ticket type in array")
            }
        }
        tasksDoneFromInsertionsWithoutTimespent = insertedTasks.reduce(into: [Ticket]())
        {
            if $1.status != .done { return }
            switch $1.ticketType
            {
            case .task(let timespent): if 0 == timespent { $0.append($1) }
            default: fatalError("Incorrect ticket type in array")
            }
        }
        
        bugsDoneFromCommitmentWithoutTimespent = committedBugs.reduce(into: [Ticket]())
        {
            if $1.status != .done { return }
            switch $1.ticketType
            {
            case .bug(let timespent): if 0 == timespent { $0.append($1) }
            default: fatalError("Incorrect ticket type in array")
            }
        }
        bugsDoneFromInsertionsWithoutTimespent = insertedBugs.reduce(into: [Ticket]())
        {
            if $1.status != .done { return }
            switch $1.ticketType
            {
            case .bug(let timespent): if 0 == timespent { $0.append($1) }
            default: fatalError("Incorrect ticket type in array")
            }
        }
    }
    let storiesWithoutStorypointsFromCommitment: [Ticket]
    let storiesWithoutStorypointsFromInsertions: [Ticket]
    
    let tasksDoneFromCommitmentWithoutTimespent: [Ticket]
    let tasksDoneFromInsertionsWithoutTimespent: [Ticket]
    
    let bugsDoneFromCommitmentWithoutTimespent: [Ticket]
    let bugsDoneFromInsertionsWithoutTimespent: [Ticket]
    
    // MARK: - Convenience getters
    /// Hours spent on bugs from commitment only
    let timespentOnBugsFromCommitment: Double
    
    /// Hours spent on tasks from commitment only
    let timespentOnTasksFromCommitment: Double
    
    /// Hours spent on bugs from interruptions only
    let timespentOnBugsFromInsertions: Double

    /// Hours spent on tasks from interruptions only
    let timespentOnTasksFromInsertions: Double

    let committedStorypoints: Double
    
    let insertedStorypoints: Double

    let totalStorypoints: Double

    // Total hours spent on bugs
    let totalTimeSpentOnBugs: Double
    
    /// Total hours spent on tasks
    let totalTimeSpentOnTasks: Double
    
    
    let storiesDoneFromCommitment: Int
    let storiesDoneFromInsertions: Int
    
    let tasksDoneFromCommitment: Int
    let tasksDoneFromInsertions: Int
    
    let bugsDoneFromCommitment: Int
    let bugsDoneFromInsertions: Int
    
    let storypointsFromCommitmentDone: Double
    let storypointsFromInsertionsDone: Double
    
    var description: String { commaSeparatedValues() }
    var debugDescription: String { description }
    
    func commaSeparatedValues() -> String
    {
        return SprintAccount.commaSeparatedValues(for: [self])
    }
    
    static func commaSeparatedValues(for sprintAccounts: [SprintAccount]) -> String
    {
        enum RowType: String, CaseIterable
        {
            case emptyRow = ""
            case sprintName = "Sprint"
            case sprintStartDate = "Sprint start"
            case headerCommitment = "\nCommitment"
            case storiesCommitted = "Stories committed"
            case storypointsCommitted = "Storypoints committed"
            case tasksCommitted = "Tasks committed"
            case bugsCommitted = "Bugs committed"
            case storiesFromCommitmentDone = "Stories from commitment done"
            case storyPointsFromCommitmentDone = "Story points from commitment done"
            case tasksFromCommitmentDone = "Tasks from commitment done"
            case timeSpentOnTasksFromCommitment = "Time spent on tasks from commitment"
            case bugsFromCommitmentDone = "Bugs from commitment done"
            case timeSpentOnBugsFromCommitment = "Time spent on bugs from commitment"
            case headerInterruptions = "\nInterruptions"
            case storiesUnplanned = "Stories unplanned"
            case storypointsUnplanned = "Storypoints unplanned"
            case tasksUnplanned = "Tasks unplanned"
            case bugsUnplanned = "Bugs unplanned"
            case storiesFromInterruptionsDone = "Stories from interruptions done"
            case storyPointsFromInterruptionsDone = "Story points from interruptions done"
            case tasksFromInterruptionsDone = "Tasks from interruptions done"
            case timeSpentOnTasksFromInterruptions = "Time spent on tasks from interruptions"
            case bugsFromInterruptionsDone = "Bugs from interruptions done"
            case timeSpentOnBugsFromInterruptions = "Time spent on bugs from interruptions"
            case headerTotals = "\nTotals"
            case totalStorypointsDone = "Total storypoints done"
            case totalTimesSpentOnTasks = "Total times spent on tasks"
            case totalTimeSpentOnBugs = "Total time spent on bugs"
            case storiesWithoutStorypoints = "Stories without storypoints"
            case doneTasksWithoutTimespent = "Done tasks without timespent"
            case doneDugsWithoutTimespent = "Done bugs without timespent"
        }
        
        let allRowTypes = RowType.allCases
        let csvItems =
        [
            RowType.sprintName,
            RowType.sprintStartDate,
            RowType.headerCommitment,
            RowType.storiesCommitted,
            RowType.storypointsCommitted,
            RowType.tasksCommitted,
            RowType.bugsCommitted,
            RowType.storiesFromCommitmentDone,
            RowType.storyPointsFromCommitmentDone,
            RowType.tasksFromCommitmentDone,
            RowType.timeSpentOnTasksFromCommitment,
            RowType.bugsFromCommitmentDone,
            RowType.timeSpentOnBugsFromCommitment,
            RowType.emptyRow,
            RowType.headerInterruptions,
            RowType.storiesUnplanned,
            RowType.storypointsUnplanned,
            RowType.tasksUnplanned,
            RowType.bugsUnplanned,
            RowType.storiesFromInterruptionsDone,
            RowType.storyPointsFromInterruptionsDone,
            RowType.tasksFromInterruptionsDone,
            RowType.timeSpentOnTasksFromInterruptions,
            RowType.bugsFromInterruptionsDone,
            RowType.timeSpentOnBugsFromInterruptions,
            RowType.emptyRow,
            RowType.headerTotals,
            RowType.totalStorypointsDone,
            RowType.totalTimesSpentOnTasks,
            RowType.totalTimeSpentOnBugs,
            RowType.storiesWithoutStorypoints,
            RowType.doneTasksWithoutTimespent,
        ]
        assert(csvItems.count >= allRowTypes.count)
        
        var csvRows = [RowType:String]()
        
        for aRowType in csvItems
        {
            csvRows[aRowType] = aRowType.rawValue
        }
            
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.current
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        
        for aSprint in sprintAccounts
        {
            /// every sprint adds a column to each row
            for aRowType in allRowTypes
            {
                switch aRowType
                {
                case .emptyRow: break
                case .sprintStartDate:
                    if let startDate = aSprint.startTime
                    {
                        let dateString = dateFormatter.string(from: startDate)
                        csvRows[aRowType]?.append(",\(dateString)")
                    }
                    else
                    {
                        csvRows[aRowType]?.append(",")
                    }
                case .headerCommitment: break
                case .headerInterruptions: break
                case .headerTotals: break
                    
                case .sprintName: csvRows[aRowType]?.append(",\(aSprint.name ?? "")")
                case .storiesCommitted: csvRows[aRowType]?.append(",\(aSprint.committedUserStories.count)")
                case .storypointsCommitted: csvRows[aRowType]?.append(",\(aSprint.committedStorypoints)")
                case .tasksCommitted: csvRows[aRowType]?.append(",\(aSprint.committedTasks.count)")
                case .bugsCommitted: csvRows[aRowType]?.append(",\(aSprint.committedBugs.count)")
                case .storiesFromCommitmentDone: csvRows[aRowType]?.append(",\(aSprint.storiesDoneFromCommitment)")
                case .storyPointsFromCommitmentDone: csvRows[aRowType]?.append(",\(aSprint.storypointsFromCommitmentDone)")
                case .tasksFromCommitmentDone: csvRows[aRowType]?.append(",\(aSprint.tasksDoneFromCommitment)")
                case .timeSpentOnTasksFromCommitment: csvRows[aRowType]?.append(",\(aSprint.timespentOnTasksFromCommitment)")
                case .bugsFromCommitmentDone: csvRows[aRowType]?.append(",\(aSprint.bugsDoneFromCommitment)")
                case .timeSpentOnBugsFromCommitment: csvRows[aRowType]?.append(",\(aSprint.timespentOnBugsFromCommitment)")
                case .storiesUnplanned: csvRows[aRowType]?.append(",\(aSprint.insertedUserStories.count)")
                case .storypointsUnplanned: csvRows[aRowType]?.append(",\(aSprint.insertedStorypoints)")
                case .tasksUnplanned: csvRows[aRowType]?.append(",\(aSprint.insertedTasks.count)")
                case .bugsUnplanned: csvRows[aRowType]?.append(",\(aSprint.insertedBugs.count)")
                case .storiesFromInterruptionsDone: csvRows[aRowType]?.append(",\(aSprint.storiesDoneFromInsertions)")
                case .storyPointsFromInterruptionsDone: csvRows[aRowType]?.append(",\(aSprint.storypointsFromInsertionsDone)")
                case .tasksFromInterruptionsDone: csvRows[aRowType]?.append(",\(aSprint.tasksDoneFromInsertions)")
                case .timeSpentOnTasksFromInterruptions: csvRows[aRowType]?.append(",\(aSprint.timespentOnTasksFromInsertions)")
                case .bugsFromInterruptionsDone: csvRows[aRowType]?.append(",\(aSprint.bugsDoneFromInsertions)")
                case .timeSpentOnBugsFromInterruptions: csvRows[aRowType]?.append(",\(aSprint.timespentOnBugsFromInsertions)")
                case .totalStorypointsDone: csvRows[aRowType]?.append(",\(aSprint.storypointsFromCommitmentDone + aSprint.storypointsFromInsertionsDone)")
                case .totalTimesSpentOnTasks: csvRows[aRowType]?.append(",\(aSprint.totalTimeSpentOnTasks)")
                case .totalTimeSpentOnBugs: csvRows[aRowType]?.append(",\(aSprint.totalTimeSpentOnBugs)")
                case .storiesWithoutStorypoints: csvRows[aRowType]?.append(",\(aSprint.storiesWithoutStorypointsFromCommitment.count + aSprint.storiesWithoutStorypointsFromInsertions.count)")
                case .doneTasksWithoutTimespent: csvRows[aRowType]?.append(",\(aSprint.tasksDoneFromInsertionsWithoutTimespent.count)")
                case .doneDugsWithoutTimespent: csvRows[aRowType]?.append(",\(aSprint.bugsDoneFromInsertionsWithoutTimespent.count)")
                }
            }
        }
        
        var cvsString = ""
        for aRowType in csvItems
        {
            if aRowType == .emptyRow { continue }
            
            guard let rowString = csvRows[aRowType]
            else { fatalError("Unexpected nil string. Was a rowType added recently?") }
            cvsString.append("\(rowString)\n")
        }
        
        return cvsString
    }
}
