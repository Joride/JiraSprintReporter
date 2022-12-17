//
//  Ticket.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

struct Ticket
{
    enum TicketType
    {
        case userStory(Double?) // associated value is the number of storypoints assigned to it
        case task(Double?)   // associated value is the timeestimate associated with it
        case bug(Double?)    // associated value is the timeestimate associated with it
        case other
    }
    
    enum Status: String
    {
        init?(rawValue: String)
        {
            switch rawValue
            {
            case "To Do": self = .todo
            case "In Progress",
                "Open",
                "Code approved",
                "On Hold",
                "Ready for QA",
                "Ready for code review",
                "Ready to deploy",
                "Needs Improvement",
                "Ready for review",
                "Design review",
                "In Delivery",
                "Review": self = .notDone
            case "Done",
                "Won't fix",
                "Closed",
                 "Delivered": self = .done
            default:
                self = .unexpected
                fatalError("\"\(rawValue)\" Unexpected Ticket Type encountered. This needs to be properly handled:")
            }
        }
        case todo
        case notDone
        case done
        case unexpected
    }
    let key: String
    let ticketType: TicketType
    let status: Status
    
    let participants: [String]?
    let assignee: String?
}
