//
//  main.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

// MARK: - Global Application Variables

/// The identifiers for the Jira projects for Recharge's engineering teams
let userprojectKeys: [String] = [
"PAY",      // Payments & Risk
"MR",       // Retention
"SHOP",     // Checkout
"MOBAPP",   // Mobile Apps
"DIS",      // Discovery
"OD",       // Orders & Delivery
"SIM",      // Supply Integation & Management
"PET",      // Platform Engineering
]

/// The cookieString obtained from Safari (or whatever browser) to connect to the JIRA api
/// Try to open this URL on your browser `https://creativegroupdev.atlassian.net/rest/agile/1.0/board`
/// and find the full cookiestring (not the separate headers)
let cookieString = "ajs_anonymous_id=%2252536d0b-e823-497d-9e9c-b3b2d3d11fbe%22; cloud.session.token=eyJraWQiOiJzZXNzaW9uLXNlcnZpY2VcL3Byb2QtMTU5Mjg1ODM5NCIsImFsZyI6IlJTMjU2In0.eyJhc3NvY2lhdGlvbnMiOltdLCJzdWIiOiI2MmQ2ZTIwZTY1N2ZjMTY2ZTI2MDM5OTkiLCJlbWFpbERvbWFpbiI6InJlY2hhcmdlLmNvbSIsImltcGVyc29uYXRpb24iOltdLCJjcmVhdGVkIjoxNjU5MzQwMjE4LCJyZWZyZXNoVGltZW91dCI6MTY3MTA0Mzk0NCwidmVyaWZpZWQiOnRydWUsImlzcyI6InNlc3Npb24tc2VydmljZSIsInNlc3Npb25JZCI6IjJiNzFkNmI4LTc1MzQtNGU1NS05ZDdlLTNmNWIwZGY2NWVmOSIsInN0ZXBVcHMiOltdLCJhdWQiOiJhdGxhc3NpYW4iLCJuYmYiOjE2NzEwNDMzNDQsImV4cCI6MTY3MzYzNTM0NCwiaWF0IjoxNjcxMDQzMzQ0LCJlbWFpbCI6ImpvcnJpdC52YW4uYXNzZWx0QHJlY2hhcmdlLmNvbSIsImp0aSI6IjJiNzFkNmI4LTc1MzQtNGU1NS05ZDdlLTNmNWIwZGY2NWVmOSJ9.eANx_lFmfIWfSGaXkHAAYoHWnBraKt_upxyWAd7fDicv4AwzIvE9fmhovEWOMkEzn4Ik67gnZ6Rl7x6sDMKAFYip3KzNcCuF85Mp0vsImg1emMmNn9p-5wl4qgtJASR-xToftANXE7x7JEs1uJKZ29flXVHEZEVRg86OPRZsdJ32TzB0-R0HJ1gfAQYhvBt4NWJLINx2cwK7AjdQCwx-iyAXrv_5FBfioEU6ACjKsJAbn-SvbRnPcFeXSua0q1-ggGlKLBI4JtGjsV8WE9JNqsLrl8vuCt5SYGF-6NUo7G6VgMaQfW4R2ihvwoZ6Gd5rME8L5bL085vgYxfse-0QMw; JSESSIONID=804FFBEEA9528B5E35C9FE89C27BF045; atlassian.xsrf.token=4e812620-4710-4353-b78a-d35220e2626a_61304be74fbce634ec5fd5846a9f330196afee6e_lin"

// MARK: - Program start
let session = URLSession(configuration: .ephemeral)
let activeSprintOnly = false
let sprintsFromYear = 2022
let sprintsFromMonth = 8

/// Get all the boards that live in Jira
guard let boards = await BoardsFetcher(cookieString: cookieString,
                                       session: session).fetch()
else
{
    print("Could not download boards from jira. Exiting now.")
    exit(1)
}

for aUserprojectKey in userprojectKeys
{
    /// MARK: - Obtain scrum board(s) for the project
    print("Obtaining scrum board(s) for \(aUserprojectKey)...")
    let matchingBoards = boards.filter{
        ($0.location?.projectKey != nil) &&
        ($0.location!.projectKey == aUserprojectKey) &&
        ($0.type == "scrum")
    }
    var boardID: Int? = nil
    
    if matchingBoards.count > 1
    {
        var boardsString = ""
        
        for index in 0 ..< matchingBoards.count
        {
            let aBoard = matchingBoards[index]
            boardsString.append("\n#\(index):\n\(aBoard)\n")
        }
        print("Multiple projects with the project-key '\(aUserprojectKey)' found:\n\(boardsString)")
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
            
            boardID = aBoard.id

        }
        else
        {
            print("No input, moving on")
        }
    }
    else if matchingBoards.count == 1
    {
        guard let aBoard = matchingBoards.first
        else { fatalError("Check for at least one board was done just before. Was the code changed recently?") }
        boardID = aBoard.id
    }
    
    if let boardID = boardID
    {
        let sprints = await SprintsFetcher(projectIdentifier: boardID,
                                           cookieString: cookieString,
                                           session: session).fetch()
        
        /// MARK: - Filter Relevant Sprints
        print("Filtering Relevant Sprints for \(aUserprojectKey)...")
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        
        var dateComponents = DateComponents()
        dateComponents.year = sprintsFromYear
        dateComponents.month = sprintsFromMonth
        
        guard let fromDate = calendar.date(from: dateComponents)
        else { fatalError("Could not create date from dateComponents") }
        
        let relevantSprints: [Sprint]
        if activeSprintOnly
        {
            relevantSprints = sprints.filter { $0.status == .active }
        }
        else
        {
            relevantSprints = sprints
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
        
        if relevantSprints.count == 0
        {
            /// this condition gets hit for instance when in planning and the
            ///  active sprint has been closed and the next one has not been
            ///  started yet
            print("No relevant sprints found for \(aUserprojectKey), moving on")
        }
        else
        {
            /// MARK: - Filter Relevant Sprints
            var sprintAccounts = [SprintAccount]()
            for aSprint in relevantSprints
            {
                print("\tObtaining full Burndown for sprint \(aSprint.name ?? (aSprint.startDate?.description ?? aSprint.id.description))...")
                
                let sprintIssueKeys = await BurndownFetcher(sprint: aSprint,
                                                            projectID: boardID,
                                                            cookieString: cookieString,
                                                            session: session).fetch()
                let insertedIssues: [Issue]
                if nil != sprintIssueKeys &&
                    !sprintIssueKeys!.insertions.isEmpty
                {
                    insertedIssues = await IssuesDetailsFetcher(issueKeys: sprintIssueKeys!.insertions,
                                                                cookieString: cookieString,
                                                                session: session).fetch() ?? []
                }
                else
                {
                    insertedIssues = []
                }
                
                let committedIssues: [Issue]
                if nil != sprintIssueKeys &&
                    !sprintIssueKeys!.commitment.isEmpty
                {
                    committedIssues = await IssuesDetailsFetcher(issueKeys: sprintIssueKeys!.commitment,
                                                                 cookieString: cookieString,
                                                                 session: session).fetch() ?? []
                }
                else
                {
                    committedIssues = []
                }
                
                
                /// MARK: - Sprint Accounting
                print("\t Sprint specific accounting...")
                let accountant = SprintAccountant(sprintID: aSprint.id,
                                                  startTime: aSprint.startDate,
                                                  endTime: aSprint.endDate,
                                                  name: aSprint.name,
                                                  goal: aSprint.goal)
                                
                let account = accountant.sprintAccount(for: committedIssues,
                                         insertedIssues: insertedIssues)
                sprintAccounts.append(account)
            }
            
            // MARK: - Exporting Sprint Accounts
            print("\t exporting \(sprintAccounts.count) \(aUserprojectKey) sprints...")
            /// NOTE, earlier, sprints were filtered
            /// to fetch only those that have a startDate
            /// so we can use `!` here
            let sortedSprints = sprintAccounts.sorted{ $0.startTime! < $1.startTime! }
            let csvString = SprintAccount.commaSeparatedValues(for: sortedSprints) as NSString
            do
            {
                let path = ("~/Desktop/\(aUserprojectKey)-sprints.txt" as NSString)
                    .expandingTildeInPath
                try csvString.write(toFile: path,
                                    atomically: true,
                                    encoding: String.Encoding.utf8.rawValue)
            }
            catch
            {
                print("could not write file to disk: \(error)")
            }
        }
    }
    else
    {
        print("No board ID for this board (project '\(aUserprojectKey)'. That shoud be impossible at this point. Moving on to next project.")
        continue
    }
}

// prevent exiting before the network calls and parsers etc have finished
// their work (as they do that asynchronously)
//dispatchMain()
