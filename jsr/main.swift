//
//  main.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Note: if this program does not compile because of this error
/// `Cannot find 'cookieString' in scope`, add a file to the project called
/// `cookiestringconstant.swift` and define a constant in it like so
/// `let cookieString = "your-cookie-string"`
/// For privacy/security reasons, this file is excluded from being commited to
/// the repo.
/// The cookieString can be obtained from Safari (or whatever browser) by
/// connecting to the JIRA api. Try to open this URL on your browser `https://creativegroupdev.atlassian.net/rest/agile/1.0/board`
/// and find the full cookiestring (not the separate headers).

/// Log this time to allow for measuring the total runtime of this application
let start = Date.now

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

/// Set to `true` to only report on the current active sprint of each board
let activeSprintOnly = false

/// Combined with `sprintsFromMonth`, the first day of the specified month in
/// the specified years is starting point in time from which to fetch sprints.
let sprintsFromYear = 2022

/// Combined with `sprintsFromYear`, the first day of the specified month in
/// the specified years is starting point in time from which to fetch sprints.
let sprintsFromMonth = 10

/// Get all the boards that live in Jira
guard let boards = await BoardsFetcher(cookieString: cookieString).fetch()
else
{
    print("Could not download boards from jira. Exiting now. Bye bye, take care.")
    exit(1)
}

/// remove all boards that are not in one of the projects listed
/// in `userprojectKeys`
let relevantProjectBoards = boards.filter{
    ($0.type == "scrum") &&
    ($0.location?.projectKey != nil) && // this line allows for the force-unwrap on the next line
    (userprojectKeys.contains($0.location!.projectKey))
}

print("Boards for which sprint reports will be generated: \(relevantProjectBoards.map{$0.name})")
do
{
    let _ = try await reportSprintsForRelevantBoards()
}
catch
{
    print("Error reportSprintsForRelevantBoards: \(error)")
}

let end = Date.now
let elapsed = end.timeIntervalSince(start)
print("Elapsed time: \(String(format: "%.3f s", elapsed))")
