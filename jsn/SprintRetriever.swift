//
//  SprintRetriever.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

class SprintRetriever
{
    private let session = URLSession(configuration: .ephemeral)
    
    private var doneTicketsInActiveSprintFetcher: DoneTicketsInActiveSprintFetcher? = nil
    private var ticketsHistoryFetcher: TicketsHistoryFetcher? = nil
    
    var dateFormatter: DateFormatter
    {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.autoupdatingCurrent
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }
    
    private func processChanges(on tickets: [JIRAIssue])
    {
        var doneTickets = [JIRAIssueChange]()
        var doneBugsWithoutTimeSpent = [JIRAIssueChange]()
        var doneTasksWithoutTimeSpent = [JIRAIssueChange]()
        var changedAssigneeWithoutParticipants = [JIRAIssueChange]()
        
        for aTicket in tickets
        {
            guard let state = aTicket.fields.status?.state
            else { fatalError("Ticket without state encountered! This is unexpected and should be reviewed.") }
            if state == .unexpected { fatalError("Ticket with unexpected state encountered! This is unexpected and should be reviewed.") }
            
            switch state
            {
            case .reopened: break
            case .open: break
            case .newTriage: break
            case .blocked: break
            case .inDesignReview: break
            case .inQA: break
            case .inReview: break
            case .inProgress: break
            case .unexpected: break
            case .closed:
                guard let doneDate = doneDate(for: aTicket)
                else { fatalError("No Done date for ticket. What is going on?") }
                
                let issueChange = JIRAIssueChange(changeDate: doneDate,
                                                  issue: aTicket)
                doneTickets.append(issueChange)
                
                if aTicket.fields.timespent == 0
                {
                    if aTicket.fields.issueType.ticketType == .bug
                    {
                        doneBugsWithoutTimeSpent.append(issueChange)
                    }
                    
                    if aTicket.fields.issueType.ticketType == .task
                    {
                        doneTasksWithoutTimeSpent.append(issueChange)
                    }
                }
            }
            if let histories = aTicket.changelog?.histories
            {
                for aHistory in histories
                {
                    for aChange in aHistory.items
                    {
                        if aChange.field == "assignee"
                        {
                            let oldAssignee = aChange.fromString ?? ""
                            if !oldAssignee.isEmpty
                            {
                                if let participants = aTicket.fields.participants
                                {
                                    if !participants.contains(where: { $0.displayName == oldAssignee })
                                    {
                                        let issueChange = JIRAIssueChange(changeDate: aHistory.created,
                                                                          issue: aTicket)
                                        changedAssigneeWithoutParticipants.append(issueChange)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let sprintReview = SprintReview(
            doneTickets: doneTickets,
            doneBugsWithoutTimeSpent:doneBugsWithoutTimeSpent,
            doneTasksWithoutTimeSpent:doneTasksWithoutTimeSpent,
            changedAssigneeWithoutParticipants: changedAssigneeWithoutParticipants)
        
        self.fetchResult(sprintReview)
    }
    
    
    /// is the issue is not Done /  completed, this function will return nil
    private func doneDate(for issue: JIRAIssue) -> Date?
    {
        guard let state = issue.fields.status?.state
        else { fatalError("Ticket without state encountered! This is unexpected and should be reviewed.") }
        
        if state == .unexpected { fatalError("Ticket with unexpected state encountered! This is unexpected and should be reviewed.") }
        
        
        if let histories = issue.changelog?.histories
        {
            for aHistory in histories
            {
                for aChange in aHistory.items
                {
                    if aChange.field == "status"
                    {
                        // confirm this is the correct aChange
                        if aChange.toString == Fields.Status.State.closed.rawValue
                        {
                            return aHistory.created
                        }
                    }
                }
            }
        }
        return nil
    }
    
    
    private let fetchResult: (SprintReview) -> (Void)
    init(cookieString: String,
         projectKey: String,
         session: URLSession? = URLSession(configuration: .ephemeral),
         fetchResult: @escaping (SprintReview) -> (Void))
    {
        self.fetchResult = fetchResult
        let ticketsInSprintFetcher = DoneTicketsInActiveSprintFetcher(projectKey: projectKey,
                                                                      cookieString: cookieString,
                                                                      session: session)
        {
            if let info = $0
            {
                let issueKeys = info.map{$0.key}
                
                let ticketsHistoryFetcher = TicketsHistoryFetcher(issueKeys: issueKeys,
                                                                  cookieString: cookieString)
                {
                    /// these are all the issues inside the sprint with their
                    /// changelogs
                    self.processChanges(on: $0)
                }
                self.ticketsHistoryFetcher = ticketsHistoryFetcher
            }
            else
            {
                print("No results")
            }
        }
        self.doneTicketsInActiveSprintFetcher = ticketsInSprintFetcher
    }
}

struct SprintReview
{
    let doneTickets: [JIRAIssueChange]
    let doneBugsWithoutTimeSpent: [JIRAIssueChange]
    let doneTasksWithoutTimeSpent: [JIRAIssueChange]
    let changedAssigneeWithoutParticipants: [JIRAIssueChange]
}


struct JIRAIssueChange
{
    let changeDate: Date
    let issue: JIRAIssue
}
