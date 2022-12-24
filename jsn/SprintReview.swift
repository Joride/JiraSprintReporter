//
//  SprintReview.swift
//  jsn
//
//  Created by Jorrit van Asselt on 20/12/2022.
//

import Foundation

/**
 A sprint review reports on things that might require immediate attention:
 - done stories ('great work!')
 - done bugs without time-spent registered (woops, someone forgot to fill in time spent)
 - done tasks without time-spent registered (woops, someone forgot to fill in time spent)
 - issues that were inserted into the sprint (are these really so urgent as to warrent breaking the sprint?)
 */
struct SprintReview
{
    let projectKey: String
    let extendedIssues: [ExtendedIssue]
    let generatedTime: Date
    let doneTickets: [JIRAIssueChange]
    let doneStories: [JIRAIssueChange]
    let doneBugsWithoutTimeSpent: [JIRAIssueChange]
    let doneTasksWithoutTimeSpent: [JIRAIssueChange]
    let addedToActiveSprint: [JIRAIssueChange]
    
    /// Returns a new SprintReview, but containting only JIRAIssues that
    /// had a change after the give date.
    /// Note: 'a change' here means a change that affected any of the specifics
    /// mentioned in this struct's description.
    init(projectKey: String,
         extendedIssues: [ExtendedIssue],
         generatedTime: Date,
         sinceDate: Date) async
    {
        self.projectKey = projectKey
        self.extendedIssues = extendedIssues
        self.generatedTime = generatedTime
        var doneTickets = [JIRAIssueChange]()
        var doneStories = [JIRAIssueChange]()
        var doneBugsWithoutTimeSpent = [JIRAIssueChange]()
        var doneTasksWithoutTimeSpent = [JIRAIssueChange]()
        var addedToActiveSprint = [JIRAIssueChange]()
        
        for anExtendedIssue in extendedIssues
        {
            
            for aHistory in (anExtendedIssue.changelog?.histories ?? [])
            {
                for anItem in aHistory.items
                {
                    if anItem.field == "Sprint"
                    {
                        let fromSprints = anItem.from?.components(separatedBy: ",")
                            .map{$0.description.trimmingCharacters(in: .whitespacesAndNewlines)}
                            .map{Int($0)}
                            .compactMap{$0}
                        ?? []
                        let toSprints = anItem.to?.components(separatedBy: ",")
                            .map{$0.description.trimmingCharacters(in: .whitespacesAndNewlines)}
                            .map{Int($0)}
                            .compactMap{$0}
                        ?? []
                        
                        let addedToSprints = Set(toSprints).subtracting(Set(fromSprints))
                        
                        for aBoardID in addedToSprints
                        {
                            do
                            {
                                
                                let sprintSummary = try await SprintSummaryFetcher(sprintID: aBoardID,
                                                                                   cookieString: cookieString).fetch()
                                if sprintSummary.state == "active"
                                {
                                    let author = aHistory.author?.displayName ??
                                    aHistory.author?.emailAddress ??
                                    "\"\""
                                    
                                    let issueChange = JIRAIssueChange(changeDate: aHistory.created,
                                                                      issue: anExtendedIssue,
                                                                      author: author)
                                    addedToActiveSprint.append(issueChange)
                                }
                            }
                            catch
                            {
//                                print("Could not obtain sprint summary for ticket \(anExtendedIssue.key): \(error)")
                            }
                        }
                    }
                }
            }
            
            guard let state = anExtendedIssue.fields.status?.state
            else { fatalError("Ticket without state encountered! This is unexpected and should be reviewed.") }
            if state == .unexpected { fatalError("Ticket with unexpected state encountered! This is unexpected and should be reviewed.") }
            
            switch state
            {
            case .qaInProgress: break
            case .review: break
            case .onHold: break
            case .readyForQA: break
            case .reopened: break
            case .needsImprovement: break
            case .readyForReview: break
            case .readyForCodeReview: break
            case .readyToDeploy: break
            case .open: break
            case .codeApproved: break
            case .todo: break
            case .newTriage: break
            case .blocked: break
            case .inDesignReview: break
            case .inQA: break
            case .inReview: break
            case .inProgress: break
            case .unexpected: break
            case .delivered: break
            case .closed, .done:
                
                guard let (doneDate, author) = anExtendedIssue.doneDate()
                else { fatalError("No Done date for a ticket that is done: \(anExtendedIssue.key)") }
                
                guard let doneDate = doneDate
                else { fatalError("No Done date for a ticket that is done: \(anExtendedIssue.key)") }
                
                let issueChange = JIRAIssueChange(changeDate: doneDate,
                                                  issue: anExtendedIssue,
                                                  author: author)
                doneTickets.append(issueChange)
                
                if anExtendedIssue.fields.timespentHours == 0
                {
                    if anExtendedIssue.fields.issueType.ticketType == .bug
                    {
                        doneBugsWithoutTimeSpent.append(issueChange)
                    }
                    
                    if anExtendedIssue.fields.issueType.ticketType == .task
                    {
                        doneTasksWithoutTimeSpent.append(issueChange)
                    }
                }
                if anExtendedIssue.fields.issueType.ticketType == .userStory
                {
                    doneStories.append(issueChange)
                }
            }
        }
        self.doneTickets = doneTickets
        self.doneStories = doneStories
        self.doneBugsWithoutTimeSpent = doneBugsWithoutTimeSpent
        self.doneTasksWithoutTimeSpent = doneTasksWithoutTimeSpent
        self.addedToActiveSprint = addedToActiveSprint
    }
}

extension SprintReview
{
    var notificationSummary: SprintNotificationSummary?
    {
        var body = ""
        
        if addedToActiveSprint.count > 0
        {
            body += (body.count > 0) ? " | " : ""
            body += "Sprint interruption"
        }
        
        if doneStories.count > 0
        {
            body += (body.count > 0) ? " | " : ""
            body += "Story done"
        }
        
        
        if doneBugsWithoutTimeSpent.count > 0
        {
            body += (body.count > 0) ? " | " : ""
            body += "Missing time in bug "
        }
        
        if doneTasksWithoutTimeSpent.count > 0
        {
            body += (body.count > 0) ? " | " : ""
            body += "Missing time in task"
        }
        
        if body.count > 0
        {
            return SprintNotificationSummary(title: projectKey,
                                             body: body,
                                             subtitle: "Sprint needs attention")
        }
        return nil
    }
}

struct SprintNotificationSummary
{
    let title: String
    let body: String
    let subtitle: String
}
