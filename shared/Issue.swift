//
//  Issue.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Typed representation of a jira issue. Used by `BurndownFetcher`,
/// `IssuesDetailsFetcher` and `SprintAccountant`
struct Issue: Decodable
{
    let key: String
    let fields: Fields
}

/// Typed representation of a the fields inside a jira issue.
struct Fields: Decodable
{
    let summary: String
    let customfield_10874: Double?
//    let customfield_10708: String?
    var timespentHours: Double?
    {
        customfield_10874
//        Double(customfield_10874 ?? "") ?? 0
    }
    
//    let validStoryPointValues: [Int] = [1,2,3,5,8,13,21,34,55,89]
//    func validateStoryPoints() -> Bool
//    {
//        validStoryPointValues.contains(storyPoints ?? 0)
//    }
    
    let storyPoints: Double?
    let issueType: IssueType
    struct IssueType: Decodable
    {
        let name: String
        
        var ticketType: TicketType
        {
            return TicketType(rawValue: name)
        }
        enum TicketType: String
        {
            init(rawValue: String)
            {
                switch rawValue
                {
                case Fields.IssueType.TicketType.bug.rawValue: self = .bug
                case Fields.IssueType.TicketType.userStory.rawValue: self = .userStory
                case Fields.IssueType.TicketType.improvement.rawValue: self = .improvement
                case Fields.IssueType.TicketType.design.rawValue: self = .design
                case Fields.IssueType.TicketType.task.rawValue: self = .task
                case Fields.IssueType.TicketType.subtask.rawValue: self = .subtask
                case Fields.IssueType.TicketType.epic.rawValue: self = .epic
                default:
                    self = .unexpected
                    fatalError("Unexpected TicketType encountered. This needs to be properly handled")
                    
                }
            }
            case epic = "Epic"
            case bug = "Bug"
            case userStory = "Story"
            case improvement = "Improvement"
            case design = "Design"
            case task = "Task"
            case subtask = "Sub-task"
            case unexpected
        }
    }
     
    let status: Status?
    struct Status: Decodable
    {
        let name: String?
        
        var state: State
        {
            return State(rawValue: name ?? "")
        }
        enum State: String
        {
            case qaInProgress = "QA in progress"
            case reopened = "Re-opened"
            case onHold = "On Hold"
            case needsImprovement = "Needs Improvement"
            case readyForQA = "Ready for QA"
            case readyForReview = "Ready for review"
            case readyForCodeReview = "Ready for code review"
            case readyToDeploy = "Ready to deploy"
            case codeApproved = "Code approved"
            case delivered = "Delivered"
            case open = "Open"
            case todo = "To Do"
            case newTriage = "New / Triage"
            case blocked = "Blocked"
            case inDesignReview = "In Design Review"
            case inQA = "In QA"
            case inReview = "In Review"
            case review = "Review"
            case closed = "Closed"
            case done = "Done"
            case inProgress = "In Progress"
            case unexpected
            init(rawValue: String)
            {
                switch rawValue
                {
                case Fields.Status.State.qaInProgress.rawValue: self = .qaInProgress
                case Fields.Status.State.review.rawValue: self = .review
                case Fields.Status.State.done.rawValue: self = .done
                case Fields.Status.State.reopened.rawValue: self = .reopened
                case Fields.Status.State.open.rawValue: self = .open
                case Fields.Status.State.onHold.rawValue: self = .onHold
                case Fields.Status.State.needsImprovement.rawValue: self = .needsImprovement
                case Fields.Status.State.readyForQA.rawValue: self = .readyForQA
                case Fields.Status.State.delivered.rawValue: self = .delivered
                case Fields.Status.State.readyForReview.rawValue: self = .readyForReview
                case Fields.Status.State.readyForCodeReview.rawValue: self = .readyForCodeReview
                case Fields.Status.State.readyToDeploy.rawValue: self = .readyToDeploy
                case Fields.Status.State.codeApproved.rawValue: self = .codeApproved
                case Fields.Status.State.todo.rawValue: self = .todo
                case Fields.Status.State.newTriage.rawValue: self = .newTriage
                case Fields.Status.State.blocked.rawValue: self = .blocked
                case Fields.Status.State.inDesignReview.rawValue: self = .inDesignReview
                case Fields.Status.State.inQA.rawValue: self = .inQA
                case Fields.Status.State.inReview.rawValue: self = .inReview
                case Fields.Status.State.closed.rawValue, "Released under Split": self = .closed
                case Fields.Status.State.inProgress.rawValue, "Ready For QA": self = .inProgress
                default:
                    self = .unexpected
                    fatalError("Unexpected TicketState encountered: \(rawValue). This needs to be properly handled")
                }
            }
        }
    }
    
    let assignee: Assignee?
    struct Assignee: Decodable
    {
        let displayName: String
    }
    
    let participants: [Participant]?
    struct Participant: Decodable
    {
        let displayName: String
    }
    enum CodingKeys: String, CodingKey
    {
        case summary
        case customfield_10874 // represents the custom 'Time Spent, Hours'
        case status
        case assignee
        case participants = "customfield_10872"
        case issueType = "issuetype"
        case storyPoints = "customfield_10037"
    }
}

