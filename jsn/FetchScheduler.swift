//
//  FetchScheduler.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

class FetchScheduler
{
    private var callback: ( () -> Void)? = nil
    private var timer: Timer? = nil
    func start(callback: @escaping () -> Void)
    {
        self.callback = callback
        let timer = Timer(fire: Date(),
                          interval: 15 * 60,
                          repeats: true)
        {
            self.timerFired(timer: $0)
        }
        RunLoop.main.add(timer, forMode: .default)
        self.timer = timer
    }
    
    private func timerFired(timer: Timer)
    {
        let startOfActiveTime = DateComponents(hour: 8, minute: 30)
        let endOfActiveTime = DateComponents(hour: 16, minute: 00)
        
        let now = Date()
        let calendar = NSLocale.current.calendar
        let nowComponents = calendar.dateComponents([.year, .month ,.day, .minute, .hour],
                                                    from: now)
        
        let startActiveComponents = DateComponents(year: nowComponents.year,
                                                   month: nowComponents.month,
                                                   day: nowComponents.day,
                                                   hour: startOfActiveTime.hour,
                                                   minute: startOfActiveTime.minute)
        let endActiveComponents = DateComponents(year: nowComponents.year,
                                                 month: nowComponents.month,
                                                 day: nowComponents.day,
                                                 hour: endOfActiveTime.hour,
                                                 minute: endOfActiveTime.minute)
        
        guard let startActiveTime = calendar.date(from: startActiveComponents),
              let endActiveTime = calendar.date(from: endActiveComponents)
        else { fatalError("Could not create start or end date") }
        
        if now > startActiveTime &&
            now < endActiveTime
        { callback?() }
    }
}
