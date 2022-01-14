//
//  BoardsFetcher.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Imports all the boards that exist in JIRA.
class BoardsFetcher
{
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    private let session: URLSession
    
    /// Should only ever be accessed on the internal queue
    private var boards = [Board]()
    
    /// internal queue for serializing accesss to the 1 `boards` property
    private let queue = DispatchQueue(label: "BoardsFetcher")
    
    init(cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral),
         fetchResult: @escaping ([Board]?) -> (Void))
    {
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
        fetch(result: fetchResult)
    }
    
    private func fetch(result: @escaping ([Board]?) -> (Void), startAt: Int = 0 )
    {
        /// https://tripactions.atlassian.net/rest/agile/1.0/board?startAt=100"
        let urlString = "https://tripactions.atlassian.net/rest/agile/1.0/board?startAt=\(startAt)"
        
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        let task = session.dataTask(with: request)
        { (data: Data?,
           response: URLResponse?,
           error: Error?) in
                        self.processResults(data: data,
                                error: error,
                                result: result)
            
        }
        let _ = task.resume()
    }
    
    
    
    private func processResults(data: Data?,
                                error: Error?,
                                result: @escaping ([Board]?) -> (Void))
    {
        if let error = error
        {
            print("Could not download ticket info: \(error)")
        }
        else
        {
            guard let jsonData = data
            else { fatalError("No error, but no data or no response either. HUH?") }
            
            do
            {
                let decoder = JSONDecoder()
                let boardResults = try decoder.decode(BoardsResults.self,
                                                        from: jsonData)
                
                queue.sync { self.boards.append(contentsOf: boardResults.values) }
                
                /// Knowing the total and the maxResults per call, this could
                /// be optimized by doing the network calls in parallel.
                if !boardResults.isLast
                {
                    fetch(result: result, startAt: self.boards.count)
                }
                else
                {
                    assert(self.boards.count == boardResults.total)
                    result(self.boards)
                }
            }
            catch
            {
                print("Could not decode JSONData: \(error)")
            }
        }
    }
}
    
struct BoardsResults: Decodable
{
    let maxResults: Int
    let startAt: Int
    let total: Int
    let isLast: Bool
    let values: [Board]
}

struct Board: Decodable, CustomStringConvertible
{
    var description: String
    {
        """
        name:\t\(name)
        type:\t\(type)
        id:\t\(id)
        \(location?.description ?? "")
        """
    }
    
    let id: Int
    let name: String
    let type: String
    
    let location: Location?
    struct Location: Decodable, CustomStringConvertible
    {
        let projectId: Int
        let displayName: String
        let projectName: String
        let projectKey: String
        let projectTypeKey: String
        let name: String
        var description: String
        {
            """
            display name:\t\(displayName)
            project name:\t\(projectName)
            name:\t\(name)
            """
        }
    }
    
}

