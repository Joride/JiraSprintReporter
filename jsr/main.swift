//
//  main.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation
// Example arguments:
// -c "ajs_anonymous_id=%2295a65932-738a-46e9-91db-3e0daba4fc40%22; ajs_group_id=null; cloud.session.token=eyJraWQiOiJzZXNzaW9uLXNlcnZpY2VcL3Byb2QtMTU5Mjg1ODM5NCIsImFsZyI6IlJTMjU2In0.eyJhc3NvY2lhdGlvbnMiOltdLCJzdWIiOiI2MGEyM2VjNTVkNjdmMjAwNjkyYWE1NmYiLCJlbWFpbERvbWFpbiI6InRyaXBhY3Rpb25zLmNvbSIsImltcGVyc29uYXRpb24iOltdLCJjcmVhdGVkIjoxNjM0MjEwNTMxLCJyZWZyZXNoVGltZW91dCI6MTY0MDE3MDQ1NSwidmVyaWZpZWQiOnRydWUsImlzcyI6InNlc3Npb24tc2VydmljZSIsInNlc3Npb25JZCI6IjZjMjNiZDcyLWQ4OGUtNDc4MC05NDlhLTc0ZTQ3MGMzZTYwYiIsImF1ZCI6ImF0bGFzc2lhbiIsIm5iZiI6MTY0MDE2OTg1NSwiZXhwIjoxNjQyNzYxODU1LCJpYXQiOjE2NDAxNjk4NTUsImVtYWlsIjoianZhbmFzc2VsdEB0cmlwYWN0aW9ucy5jb20iLCJqdGkiOiI2YzIzYmQ3Mi1kODhlLTQ3ODAtOTQ5YS03NGU0NzBjM2U2MGIifQ.nh-cIPGdzlo-NOiJXeeF0IVczgi8ZUc9cq0qoTGR63eg-i059ALa3lpxpQ8lSQcVXQdgxcaUCNMsACljrD-y3LmhCa0GddenaYM5Cy8wFNIquv3wfTIg7a3dMpf6a1sZdDkP3VEA73L8tSw5B7cB5D1_EugwpNw0rw4HD5-0YPkX5RexYNhCnof_TAQb2ipiM_86IobUqWvBzpJ34In_A3YgdCUaWfrWqYHe092zvlXKXIjiyT9QEp9lEUZ0LqkfTN_lMR1WY1MRXYooR4UFDCKgQtop47I9Zxr-Blk5Rn5sJJ-cPY4yMNKmhIGR5SRlsUZqvqPuhq5L5-5czj25uQ; AJS.conglomerate.cookie=\"|com.innovalog.jmwe.jira-misc-workflow-extensions$$is_user_admin=60a23ec55d67f200692aa56f/user\"; JSESSIONID=76A566E55A214E170331D20F7B311EE3; __awc_tld_test__=tld_test; atlassian.xsrf.token=b38f75f3-7759-44f9-9f16-5cbbc9ed9706_a970c9cb55a665bbbd2b4436a17647091d325ccf_lin" -p "EET" -a


let args = CommandLine.arguments
var cookieString: String? = nil
var userprojectKey: String? = nil
var activeSprintOnly = false

let usageString =
"""
This utility uses the JIRA api to report some statistics on the sprints of the desired project.
These statistics are specifically tuned to how the author is running his scrum teams, and allow for focussing on optimizing the efficiency of the team.

Usage
sr -c "cookie-string" -p "project-key" [-a]
"cookie-string" is the string used by a browser after authentication. This string must have a non-zero length.
"project-key" is the name of the project you are interest in, e.g. "EET", "AVI", "SEV", etc. This string must have a non-zero length.
-a is an optional flag. When present, only the active sprint gets reported

Jorrit van Asselt - jvanasselt@tripactions.com
"""

if args.count < 5 { fatalError("Incorrect number of arguments. \(usageString)") }

for index in 1 ..< args.count
{
    let arg = args[index]
    switch index
    {
    case 1: if arg != "-c" { fatalError("Incorrect arguments. \(usageString)") }
    case 2:
        cookieString = arg
        if arg.count == 0 { fatalError("Incorrect arguments. \(usageString)") }
    case 3: if arg != "-p" { fatalError("Incorrect arguments. \(usageString)") }
    case 4:
        userprojectKey = arg
        if arg.count == 0 { fatalError("Incorrect arguments. \(usageString)") }
    case 5:
        if arg != "-a"
        { fatalError("Incorrect arguments. \(usageString)") }
        else
        {
            activeSprintOnly = true
        }
    default: break
    }
}

var sprintCount = 0
var sprints = [SprintAccount]()
private let session = URLSession(configuration: .ephemeral)


guard let cookie = cookieString
else { fatalError( "Nil value for cookiestring" )  }
guard let projectKey = userprojectKey
else { fatalError( "Nil value for projectkey" )  }

var projectID: Int? = nil

var queue = DispatchQueue(label: "main")

var burndownFetchers =  [BurndownFetcher]()
var sprintAccountants = [SprintAccountant]()
var issuesDetailsFetcher: IssuesDetailsFetcher? = nil
var sprintInfoFetcher: SprintsFetcher? = nil

let boardsFetcher = BoardsFetcher(cookieString: cookie)
{
    if let info = $0
    {
        let matchingBoards = info.filter{
            ($0.location?.projectKey != nil) &&
            ($0.location!.projectKey == userprojectKey)
        }
        
        if matchingBoards.count > 1
        {
            var boardsString = ""
            
            for index in 0 ..< matchingBoards.count
            {
                let aBoard = matchingBoards[index]
                boardsString.append("\n#\(index):\n\(aBoard)\n")
            }
            print("Multiple projects with the project-key '\(userprojectKey ?? "")' found:\n\(boardsString)")
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
                
                fetchSprintInfo(projectIdentifier: aBoard.id)
                
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

func fetchSprintInfo(projectIdentifier: Int)
{
    sprintInfoFetcher = SprintsFetcher(projectIdentifier: projectIdentifier,
                                           cookieString: cookie,
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
            if activeSprintOnly
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
            
            sprintCount = relevantSprints.count
            for aSprint in relevantSprints
            {
                let newBurndownFetcher = BurndownFetcher(sprint: aSprint,
                                                         projectID: projectIdentifier,
                                                         cookieString: cookie,
                                                         session: session)
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
                            queue.sync
                            {
                                sprints.append(sprintAccount)
                                if sprints.count == sprintCount
                                {
                                    /// NOTE, earlier, sprints were filtered
                                    /// to fetch only those that have a startDate
                                    /// so we can use `!` here
                                    let sortedSprints = sprints.sorted{ $0.startTime! < $1.startTime! }
                                    let csvString = SprintAccount.commaSeparatedValues(for: sortedSprints) as NSString
                                    do
                                    {
                                        let path = ("~/Desktop/\(projectKey)-sprints.txt" as NSString)
                                            .expandingTildeInPath
                                        try csvString.write(toFile: path,
                                                            atomically: true,
                                                            encoding: String.Encoding.utf8.rawValue)
                                    }
                                    catch
                                    {
                                        print("could not write file to disk: \(error)")
                                    }
                                    // program done.
                                    exit(0)
                                }
                            }
                        }
                        
                        // keep it alive so the completionhandler actually runs
                        sprintAccountants.append(accountant)
                        
                        if !info.commitment.isEmpty
                        {
                            fetchIssues(withKeys: info.commitment)
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
                                fetchIssues(withKeys: info.insertions)
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
                            queue.sync { sprintCount -= 1 }
                        }
                    }
                    else
                    {
                        print("No info")
                    }
                }
                // keep alive
                queue.async { burndownFetchers.append(newBurndownFetcher) }
            }
        }
        else
        {
            print("No info, there should be an error here")
        }
    }
}

func fetchIssues(withKeys issueKeys: Set<String>,
                 result: @escaping ([Issue]?) -> Void)
{
    let issuesFetcher = IssuesDetailsFetcher(issueKeys: issueKeys,
                                             cookieString: cookie,
                                             session: session)
    {
        result($0)
    }
    issuesDetailsFetcher = issuesFetcher
}


// prevent exiting before the network calls and parsers etc have finished
// their work (as they do that asynchronously)
dispatchMain()


