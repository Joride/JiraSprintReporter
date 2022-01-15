//
//  SprintReportsGenerator.swift
//  jsn
//
//  Created by Jorrit van Asselt on 15/01/2022.
//

import Foundation

class SprintReportsGenerator
{
    let cookieString: String
    let projectKey: String
    let activeSprintOnly: Bool
    
    private var sprintCount = 0
    private var sprints = [SprintAccount]()
    private let session = URLSession(configuration: .ephemeral)
    private var projectID: Int? = nil
    private var queue = DispatchQueue(label: "SprintReportsGenerator")
    private var burndownFetchers =  [BurndownFetcher]()
    private var sprintAccountants = [SprintAccountant]()
    private var issuesDetailsFetcher: IssuesDetailsFetcher? = nil
    private var sprintInfoFetcher: SprintsFetcher? = nil

    init(cookieString: String,
         projectKey: String,
         activeSprintOnly: Bool)
    {
        self.cookieString = cookieString
        self.projectKey = projectKey
        self.activeSprintOnly = activeSprintOnly
    }
    
    private var boardsFetcher: BoardsFetcher? =  nil
    private var completion: (() -> Void)? = nil
    func generateReports(completion: @escaping () -> Void)
    {
        assert(nil == self.completion)
        
        self.completion = completion
        self.boardsFetcher = BoardsFetcher(cookieString: cookieString)
        {
            if let info = $0
            {
                let matchingBoards = info.filter{
                    ($0.location?.projectKey != nil) &&
                    ($0.location!.projectKey == self.projectKey)
                }
                
                if matchingBoards.count > 1
                {
                    var boardsString = ""
                    
                    for index in 0 ..< matchingBoards.count
                    {
                        let aBoard = matchingBoards[index]
                        boardsString.append("\n#\(index):\n\(aBoard)\n")
                    }
                    print("Multiple projects with the project-key '\(self.projectKey)' found:\n\(boardsString)")
                    print("Please enter the index of which one to use")
                    if let index = readLine()
                    {
                        guard let indexAsInt = Int(index)
                        else {
                            print("You gave the index '\(index)', but I could not make this into an integer. Exiting with exit code 1")
                            exit(1)
                        }
                        if indexAsInt >= matchingBoards.count
                        {
                            print("You gave the index '\(indexAsInt)', but maximum is \(matchingBoards.count - 1). Exiting with exitcode 1")
                            exit(1)
                        }
                        print("You gave index \(indexAsInt), so continuing with:\n\(matchingBoards[indexAsInt])")
                        // we have a valid index
                        let aBoard = matchingBoards[indexAsInt]
                        
                        self.fetchSprintInfo(projectIdentifier: aBoard.id)
                        
                    }
                    else
                    {
                        print("No input, exiting with exitcode 1")
                        exit(1)
                    }
                }
            }
            else
            {
                print("Could not get boards")
            }
        }
    }
    
    private func fetchSprintInfo(projectIdentifier: Int)
    {
        sprintInfoFetcher = SprintsFetcher(projectIdentifier: projectIdentifier,
                                           cookieString: self.cookieString,
                                           session: session)
        {
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
            calendar.locale = Locale(identifier: "en_US_POSIX")
            
            var dateComponents = DateComponents()
            dateComponents.year = 2021
            dateComponents.month = 1
            
            guard let fromDate = calendar.date(from: dateComponents)
            else { fatalError("Could not create date from dateComponents") }
            
            if let info = $0
            {
                let relevantSprints: [Sprint]
                if self.activeSprintOnly
                {
                    relevantSprints = info.filter { $0.status == .active }
                }
                else
                {
                    relevantSprints = info
                        .filter { $0.startDate != nil }
                        .filter { $0.startDate! > fromDate }
                }
                
                /// e.g. when in planning and the active sprint has been closed
                /// and the next one has not been started yet
                if relevantSprints.count == 0
                {
                    print("No relevant sprints found, exiting with code 1")
                    exit(1)
                }
                
                self.sprintCount = relevantSprints.count
                for aSprint in relevantSprints
                {
                    let newBurndownFetcher = BurndownFetcher(sprint: aSprint,
                                                             projectID: projectIdentifier,
                                                             cookieString: self.cookieString,
                                                             session: self.session)
                    {
                        if let info = $0
                        {
                            let accountant = SprintAccountant(sprintID: aSprint.id,
                                                              startTime: aSprint.startDate,
                                                              endTime: aSprint.endDate,
                                                              name: aSprint.name,
                                                              goal: aSprint.goal)
                            { (sprintAccount: SprintAccount) in
                                // essentially, this is the endresult of this entire program
                                self.queue.sync
                                {
                                    self.sprints.append(sprintAccount)
                                    if self.sprints.count == self.sprintCount
                                    {
                                        /// NOTE, earlier, sprints were filtered
                                        /// to fetch only those that have a startDate
                                        /// so we can use `!` here
                                        let sortedSprints = self.sprints.sorted{ $0.startTime! < $1.startTime! }
                                        let csvString = SprintAccount.commaSeparatedValues(for: sortedSprints) as NSString
                                        do
                                        {
                                            let path = ("~/Desktop/\(self.projectKey)-sprints.txt" as NSString)
                                                .expandingTildeInPath
                                            try csvString.write(toFile: path,
                                                                atomically: true,
                                                                encoding: String.Encoding.utf8.rawValue)
                                        }
                                        catch
                                        {
                                            print("could not write file to disk: \(error)")
                                        }
                                        self.completion?()
                                    }
                                }
                            }
                            
                            // keep it alive so the completionhandler actually runs
                            self.sprintAccountants.append(accountant)
                            
                            if !info.commitment.isEmpty
                            {
                                self.fetchIssues(withKeys: info.commitment)
                                {
                                    if let info = $0
                                    {
                                        accountant.set(committedIssues: info)
                                    }
                                    else
                                    {
                                        print("No info, there should be an error here")
                                    }
                                }
                                if info.insertions.isEmpty
                                {
                                    accountant.set(insertedIssues: [])
                                }
                                else
                                {
                                    self.fetchIssues(withKeys: info.insertions)
                                    {
                                        if let info = $0
                                        {
                                            accountant.set(insertedIssues: info)
                                        }
                                        else
                                        {
                                            print("No info, there should be an error here")
                                        }
                                    }
                                }
                            }
                            else
                            {
                                self.queue.sync { self.sprintCount -= 1 }
                            }
                        }
                        else
                        {
                            print("No info")
                        }
                    }
                    // keep alive
                    self.queue.async { self.burndownFetchers.append(newBurndownFetcher) }
                }
            }
            else
            {
                print("No info, there should be an error here")
            }
        }
    }
    
    private func fetchIssues(withKeys issueKeys: Set<String>,
                             result: @escaping ([Issue]?) -> Void)
    {
        let issuesFetcher = IssuesDetailsFetcher(issueKeys: issueKeys,
                                                 cookieString: self.cookieString,
                                                 session: session)
        {
            result($0)
        }
        issuesDetailsFetcher = issuesFetcher
    }
}
