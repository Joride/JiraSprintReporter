//
//  SprintAccountant.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/**
 This is a **single-use class**: instanciate one, set both of its properties once, and
 after both have been set, the callback that the instance is initialized with will
 be called.
 After that, this class has served its purpose and should be discarded.
 */
class SprintAccountant
{
    private var queue = DispatchQueue(label: "SprintAccountant")
    private let sprintAccount: (SprintAccount) -> Void
    
    /// The sprintID this instance was initialized with
    let sprintID: Int
    
    /// The startTime this instance was initialized with
    let startTime: Date?
    
    /// The endTime this instance was initialized with
    let endTime: Date?
    
    /// The name this instance was initialized with
    let name: String?
    
    /// The goal this instance was initialized with
    let goal: String?
    
    init(sprintID: Int,
         startTime: Date?,
         endTime: Date?,
         name: String?,
         goal: String?,
         sprintAccount: @escaping (SprintAccount) -> Void)
    {
        self.sprintID = sprintID
        self.sprintAccount = sprintAccount
        self.startTime = startTime
        self.endTime = endTime
        self.name = name
        self.goal = goal
       
    }
    private var _committedIssues: [Issue]? = nil
    func set(committedIssues: [Issue])
    {
        // if both `_commitedIssues` and `_insertedIssues` are non-nil, they can be processed
        queue.async
        {
            /// `_committedIssues` can only be set once
            assert(nil == self._committedIssues)
            self._committedIssues = committedIssues
            
            /// if both `_commitedIssues` and `_insertedIssues` are non-nil, they can be processed
            if nil != self._insertedIssues { self.processIssues() }
        }
    }
    
    private var _insertedIssues: [Issue]? = nil
    func set(insertedIssues: [Issue])
    {
        /// if both `_commitedIssues` and `_insertedIssues` are non-nil, they can be processed
        queue.async
        {
            /// `_insertedIssues` can only be set once
            assert(nil == self._insertedIssues)
            self._insertedIssues = insertedIssues
            
            if nil != self._committedIssues { self.processIssues() }
        }
    }
    
    private func processIssues()
    {
        guard let committedIssues = _committedIssues,
                let insertedIssues = _insertedIssues
        else { fatalError("Nil value found for committed issues or inserted issues") }
                
        func separate(storiesBugsAndTasksFrom issues: [Issue]) -> (stories: [Ticket],
                                                                   bugs: [Ticket],
                                                                   tasks: [Ticket])
        {
            var stories = [Ticket]()
            var bugs = [Ticket]()
            var tasks = [Ticket]()
            for anIssue in issues
            {
                let status = Ticket.Status(rawValue: anIssue.fields.status?.name ?? "") ?? .unexpected
                if .unexpected == status { continue }
                
                switch anIssue.fields.issueType.name
                {
                case "Story":
                    stories.append(
                        Ticket(key: anIssue.key,
                               ticketType: .userStory(anIssue.fields.storyPoints),
                               status: status,
                               participants: anIssue.fields.participants?.map{$0.displayName},
                               assignee: anIssue.fields.assignee?.displayName) )
                case "Bug":
                    bugs.append(
                        Ticket(key: anIssue.key,
                               ticketType: .bug(anIssue.fields.timespentHours),
                               status: status,
                               participants: anIssue.fields.participants?.map{$0.displayName},
                               assignee: anIssue.fields.assignee?.displayName) )
                case "Task":
                    tasks.append(
                        Ticket(key: anIssue.key,
                               ticketType: .task(anIssue.fields.timespentHours),
                               status: status,
                               participants: anIssue.fields.participants?.map{$0.displayName},
                               assignee: anIssue.fields.assignee?.displayName) )
                    
                default: break
                }
            }
            return (stories: stories,
                    bugs: bugs,
                    tasks: tasks)
        }
        
        let separatedCommittedTickets = separate(storiesBugsAndTasksFrom: committedIssues)
        let separatedInsertedTickets = separate(storiesBugsAndTasksFrom: insertedIssues)
        
        let newSprintAccount = SprintAccount(sprintID: sprintID,
                                             startTime: startTime,
                                             endTime: endTime,
                                             name: name,
                                             goal: goal,
                                             committedUserStories: separatedCommittedTickets.stories,
                                             committedTasks: separatedCommittedTickets.tasks,
                                             committedBugs: separatedCommittedTickets.bugs,
                                             insertedUserStories: separatedInsertedTickets.stories,
                                             insertedTasks: separatedInsertedTickets.tasks,
                                             insertedBugs: separatedInsertedTickets.bugs)
        
        sprintAccount(newSprintAccount)
    }
}
