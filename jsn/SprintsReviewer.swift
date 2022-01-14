//
//  SprintsReviewer.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

class SprintsReviewer
{
    private let PreviousFetchDateKey = "PreviousFetchDateKey"
    
    private let cookieString: String
    private let serialQueue = DispatchQueue(label: "isFetchingByKey")
    private var sprintRetriever: SprintRetriever? = nil
    private var reviewResult: (([String : SprintRapport]) -> (Void))? = nil
    private var remainingProjectKeys = Set<String>()
    private let session: URLSession
    private var resultsByKey = [String : SprintRapport]()
    
    private var dateFormatter: DateFormatter
    {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.autoupdatingCurrent
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }
       
    init(cookieString: String,
         session: URLSession = URLSession(configuration: .ephemeral))
    {
        self.cookieString = cookieString
        self.session = session
    }
    
    func fetchSprintReviewResults(for projectKeys: Set<String>,
                                     reviewResult: @escaping ([String : SprintRapport]) -> (Void))
    {
        serialQueue.sync { if remainingProjectKeys.count > 0 { return } }
        self.reviewResult = reviewResult
        remainingProjectKeys = projectKeys
        for aKey in projectKeys
        {
            DispatchQueue.global().async
            {
                self.reviewSprint(with: aKey)
            }
        }
    }
    
    private func reviewSprint(with projectKey: String)
    {
        let key = "\(PreviousFetchDateKey)-\(projectKey)"
        UserDefaults.standard.setValue(nil, forKey: key)
        UserDefaults.standard.synchronize()
        
        let previousFetchDate: Date
        if let cachedPreviousFetchDate = UserDefaults.standard.value(forKey: key) as? TimeInterval
        {
            previousFetchDate = Date(timeIntervalSince1970: cachedPreviousFetchDate)
        }
        else
        {
            previousFetchDate = Date.distantPast
        }
        let now = Date()
        let sprintRetriever = SprintRetriever(cookieString: cookieString,
                                              projectKey: projectKey)
        {
            /*
             go over each issue and report:
             * stories that moved to done (this allows to do a check on whether definition of done had been reached)
             * Tasks and Bugs that moved to done without 'timespent' logged (list participants)
             * Issues that changed assignee without updating (participants)
             * tickets that were inserted into the sprint (and how long ago that was)
             */
            
            let doneSinceLastCheck = $0.doneTickets.filter { $0.changeDate > previousFetchDate }
            let doneBugsWithoutTimeSpentSinceLastCheck = $0.doneBugsWithoutTimeSpent.filter { $0.changeDate > previousFetchDate }
            let doneTasksWithoutTimeSpentSinceLastCheck = $0.doneTasksWithoutTimeSpent.filter { $0.changeDate > previousFetchDate }
            let changedAssigneeWithoutParticipantsSinceLastCheck = $0.changedAssigneeWithoutParticipants.filter { $0.changeDate > previousFetchDate }
            
            
            var details = "Changes since \(self.dateFormatter.string(from: previousFetchDate)):\n"
            var summary = ""
            if doneSinceLastCheck.count > 0
            {
                summary += "\(doneSinceLastCheck.count) done"
                details += "Moved to 'Done':\n\(doneSinceLastCheck.map{$0.issue.key})\n"
            }
            
            if doneBugsWithoutTimeSpentSinceLastCheck.count > 0 ||
                doneTasksWithoutTimeSpentSinceLastCheck.count > 0
            {
                let issueCount = doneTasksWithoutTimeSpentSinceLastCheck.count +
                doneBugsWithoutTimeSpentSinceLastCheck.count
                if summary.count > 0 { summary += "; " }
                summary += "\(issueCount) without timeSpent"
            }
            
            if doneBugsWithoutTimeSpentSinceLastCheck.count > 0
            {
                if details.count > 0 { details += "\n" }
                details += "Bugs that moved to 'Done' without a value in 'timeSpent':\n\(doneBugsWithoutTimeSpentSinceLastCheck.map{$0.issue.key})\n"
            }
            
            if doneTasksWithoutTimeSpentSinceLastCheck.count > 0
            {
                if details.count > 0 { details += "\n" }
                details += "Tasks that moved to 'Done' without a value in 'timeSpent':\n\(doneTasksWithoutTimeSpentSinceLastCheck.map{$0.issue.key})\n"
            }
            
            if changedAssigneeWithoutParticipantsSinceLastCheck.count > 0
            {
                if summary.count > 0 { summary += "; " }
                summary += "\(changedAssigneeWithoutParticipantsSinceLastCheck.count) with incorrect participants"
            }
            
            if changedAssigneeWithoutParticipantsSinceLastCheck.count > 0
            {
                if details.count > 0 { summary += "\n" }
                details += "Tickets with incorrect participants: \(changedAssigneeWithoutParticipantsSinceLastCheck.map{$0.issue.key})\n"
            }
            
            self.serialQueue.sync
            {
                if summary.count > 0
                {
                    self.resultsByKey[projectKey] = SprintRapport(summary: summary,
                                                                  details: details)
                }
                
                self.remainingProjectKeys.remove(projectKey)
//                UserDefaults.standard.setValue(now, forKey: key)
//                UserDefaults.standard.synchronize()
                if self.remainingProjectKeys.isEmpty
                {
                    self.reviewResult?(self.resultsByKey)
                }
            }
        }
        self.sprintRetriever = sprintRetriever
    }
}

struct SprintRapport
{
    let summary: String
    let details: String
}
