//
//  SprintReviewer.swift
//  jsn
//
//  Created by Jorrit van Asselt on 18/12/2022.
//

import Cocoa

/**
 Fetches ALL issues currently in the sprint that are not of type sub-task,
 and will review the following for each:
 * _stories_ that moved to done (this allows to do a check on whether definition of done had been reached)
 * _Tasks_ and _Bugs_ that moved to done without `timespent` logged (list participants)
 * Issues that changed assignee without updating (participants)
 * Any ticket (that is not of type sub-task) that were inserted into the sprint (and how long ago that was)
 */
class SprintIssuesFetcher: NSObject
{
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    let projectKey: String
    
    /// internal queue for serializing accesss to the 1 `issues` property
    /// while populating it with repeated network calls
    private let queue = DispatchQueue(label: "SprintReviewer")
    
    /// Should only ever be accessed on the internal queue
    private var issues = [Issue]()
    
    private let session: URLSession
    
    init(projectKey: String,
        cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.projectKey = projectKey
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    
    func fetch(startAt: Int = 0) async -> [Issue]?
    {
        let jqlQuery = "project%20=%20\(projectKey)%20AND%20Sprint%20in%20openSprints()%20and%20type%20!=%20Sub-task"
        let urlString = "https://creativegroupdev.atlassian.net/rest/api/3/search?jql=\(jqlQuery)&startAt=\(startAt)"
           
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url,
                                                 cookieString: cookieString)
        do
        {
            let (data, response) = try await session.data(for: request)
            response.checkRateLimit()
            
            let decoder = JSONDecoder()
            let tickets = try decoder.decode(SprintTickets.self,
                                                    from: data)
            
            /// serialize access to the mutable array `boards`
            queue.sync { self.issues.append(contentsOf: tickets.issues) }
            
            if tickets.total > (tickets.startAt + tickets.issues.count)
            {
                // calling fetch again will append new results to the private
                // instance variable. Which is the variable we return once
                // we reach the last set, so no need to capture the return value
                // here.
                let _ = await fetch(startAt: tickets.startAt + tickets.issues.count )
            }
        }
        catch
        {
            print("Could not download data for \(request.url?.description ?? "no url in the request!"): \(error)")
        }
        return self.issues
    }
}
struct SprintTickets: Decodable
{
    let startAt: Int
    let maxResults: Int
    let total: Int
    let issues: [Issue]
}

struct SprintReview
{
    init(projectKey: String,
        extendedIssues: [ExtendedIssue])
    {
        self.projectKey = projectKey
        self.extendedIssues = extendedIssues
        var doneTickets = [JIRAIssueChange]()
        var doneBugsWithoutTimeSpent = [JIRAIssueChange]()
        var doneTasksWithoutTimeSpent = [JIRAIssueChange]()
        var changedAssigneeWithoutParticipants = [JIRAIssueChange]()
        
        for anExtendedIssue in extendedIssues
        {
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
                guard let doneDate = anExtendedIssue.doneDate()
                else { fatalError("No Done date for ticket. What is going on?") }
                
                let issueChange = JIRAIssueChange(changeDate: doneDate,
                                                  issue: anExtendedIssue)
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
            }
            if let histories = anExtendedIssue.changelog?.histories
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
                                if let participants = anExtendedIssue.fields.participants
                                {
                                    if !participants.contains(where: { $0.displayName == oldAssignee })
                                    {
                                        let issueChange = JIRAIssueChange(changeDate: aHistory.created,
                                                                          issue: anExtendedIssue)
                                        changedAssigneeWithoutParticipants.append(issueChange)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        self.doneTickets = doneTickets
        self.doneBugsWithoutTimeSpent = doneBugsWithoutTimeSpent
        self.doneTasksWithoutTimeSpent = doneTasksWithoutTimeSpent
        self.changedAssigneeWithoutParticipants = changedAssigneeWithoutParticipants
    }
    let projectKey: String
    let extendedIssues: [ExtendedIssue]
    let doneTickets: [JIRAIssueChange]
    let doneBugsWithoutTimeSpent: [JIRAIssueChange]
    let doneTasksWithoutTimeSpent: [JIRAIssueChange]
    let changedAssigneeWithoutParticipants: [JIRAIssueChange]
}


struct JIRAIssueChange
{
    let changeDate: Date
    let issue: ExtendedIssue
}
