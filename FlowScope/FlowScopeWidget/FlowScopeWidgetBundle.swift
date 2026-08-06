//
//  FlowScopeWidgetBundle.swift
//  FlowScopeWidget
//
//  Created by knightzzy on 04/08/2026.
//

import WidgetKit
import SwiftUI

@main
struct FlowScopeWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live session + today's totals
        FlowScopeWidget()
        // Lock Screen / Dynamic Island
        FlowScopeWidgetLiveActivity()
        // Gallery
        StreakWidget()
        MoodTrendWidget()
        WeeklyWidget()
        QuickStartWidget()
        CategoriesWidget()
    }
}
