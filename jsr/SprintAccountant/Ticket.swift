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
        case userStory(Int?) // associated value is the number of storypoints assigned to it
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
            case "Open", "open", "New / Triage": self = .todo
            case "In Design Review", "In Progress", "Blocked", "In Review", "Re-opened", "In QA", "Ready For QA": self = .notDone
            case "Closed", "Released under Split": self = .done
            default:
                self = .unexpected
                fatalError("Unexpected Ticket Type encountered. This needs to be properly handled")
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
