//
//  Issue.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

struct Issue: Decodable
{
    let key: String
    let fields: Fields
}

struct Fields: Decodable
{
    let customfield_10874: Double?
//    let customfield_10708: String?
    var timespentHours: Double
    {
        customfield_10874 ?? 0
//        Double(customfield_10874 ?? "") ?? 0
    }
    let storyPoints: Int?
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
                default:
                    self = .unexpected
                    fatalError("Unexpected TicketType encountered. This needs to be properly handled")
                    
                }
            }
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
            case reopened = "Re-opened"
            case open = "Open"
            case newTriage = "New / Triage"
            case blocked = "Blocked"
            case inDesignReview = "In Design Review"
            case inQA = "In QA"
            case inReview = "In Review"
            case closed = "Closed"
            case inProgress = "In Progress"
            case unexpected
            init(rawValue: String)
            {
                switch rawValue
                {
                case Fields.Status.State.reopened.rawValue: self = .reopened
                case Fields.Status.State.open.rawValue: self = .open
                case Fields.Status.State.newTriage.rawValue: self = .newTriage
                case Fields.Status.State.blocked.rawValue: self = .blocked
                case Fields.Status.State.inDesignReview.rawValue: self = .inDesignReview
                case Fields.Status.State.inQA.rawValue: self = .inQA
                case Fields.Status.State.inReview.rawValue: self = .inReview
                case Fields.Status.State.closed.rawValue, "Released under Split": self = .closed
                case Fields.Status.State.inProgress.rawValue, "Ready For QA": self = .inProgress
                default:
                    self = .unexpected
                    fatalError("Unexpected TicketState encountered. This needs to be properly handled")
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
        case customfield_10874 // represents the custom 'Time Spent, Hours'
        case status
        case assignee
        case participants = "customfield_10872"
        case issueType = "issuetype"
        case storyPoints = "customfield_10057"
    }
}

