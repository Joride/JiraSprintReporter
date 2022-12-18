//
//  Global Functions.swift
//  jsr
//
//  Created by Jorrit van Asselt on 18/12/2022.
//

import Foundation

public func reportSprintsForRelevantBoards() async throws -> [Bool]
{
    try await withThrowingTaskGroup(of: Bool.self) { group in

        for aBoard in relevantProjectBoards
        {
            group.addTask { await reportSprints(for: aBoard) }
        }

        var result = [Bool]()
        for try await success in group
        {
            result.append(success)
        }

        return result
    }
}

/// The `meat` of the program: fetches some high-level sprint info, uses that
/// to fetch full details on a number of tickets, then does some accounting
/// and outputs some csv formatted string this then save to the Desktop.
@Sendable func reportSprints(for aBoard: Board) async -> Bool
{
    // can't build the various network calls withut a project key,
    // so if it nos there, continue on. Unlikely to actually happen,
    // as the boards were filterd on having this value earlier.
    guard let userprojectKey = aBoard.location?.projectKey
    else { return false}
       
    let boardID = aBoard.id
    let sprints = await SprintsFetcher(projectIdentifier: boardID,
                                       cookieString: cookieString).fetch()
    
    let relevantSprints = filterAndSortRelevantSprints(from: sprints)
    if relevantSprints.count == 0
    {
        /// this condition gets hit for instance when in planning and the
        ///  active sprint has been closed and the next one has not been
        ///  started yet
        print("No relevant sprints found for \(userprojectKey), moving on")
        return false
    }

    var sprintAccounts = [SprintAccount]()
    for aSprint in relevantSprints
    {
        let (committedIssues, insertedIssues) = await obtainFullBurndown(for: aSprint,
                                                                         inBoard: boardID)
        /// MARK: - Sprint Accounting
        let accountant = SprintAccountant(sprintID: aSprint.id,
                                          startTime: aSprint.startDate,
                                          endTime: aSprint.endDate,
                                          name: aSprint.name,
                                          goal: aSprint.goal)
        
        let account = accountant.sprintAccount(for: committedIssues,
                                               insertedIssues: insertedIssues)
        sprintAccounts.append(account)
    }
    
    export(sprintAccounts: sprintAccounts,
           userprojectKey: userprojectKey,
           boardName: aBoard.name)
    return true
}

@Sendable func filterAndSortRelevantSprints(from sprints: [Sprint]) -> [Sprint]
{
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
            .sorted { $0.startDate! < $1.startDate! }
    }
    
    return relevantSprints
}

@Sendable func obtainFullBurndown(for aSprint: Sprint,
                        inBoard boardID: Int) async -> (committedIssues: [Issue],
                                                                             insertIssues: [Issue])
{
    let sprintIssueKeys = await BurndownFetcher(sprint: aSprint,
                                                projectID: boardID,
                                                cookieString: cookieString).fetch()
    let insertedIssues: [Issue]
    if nil != sprintIssueKeys &&
        !sprintIssueKeys!.insertions.isEmpty
    {
        insertedIssues = await IssuesDetailsFetcher(issueKeys: sprintIssueKeys!.insertions,
                                                    cookieString: cookieString).fetch() ?? []
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
                                                     cookieString: cookieString).fetch() ?? []
    }
    else
    {
        committedIssues = []
    }
    return (committedIssues, insertedIssues)
}

@Sendable func  export(sprintAccounts: [SprintAccount],
             userprojectKey: String,
             boardName: String)
{
    /// NOTE, earlier, sprints were filtered
    /// to fetch only those that have a startDate
    /// so we can use `!` here
    let sortedSprints = sprintAccounts.sorted{ $0.startTime! < $1.startTime! }
    let csvString = SprintAccount.commaSeparatedValues(for: sortedSprints) as NSString
    do
    {
        let path = ("~/Desktop/\(userprojectKey)-\(boardName)-sprints.txt" as NSString)
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
