//
//  MeetingsView.swift
//  Shepherd
//

import SwiftUI

struct MeetingsView: View {
    var body: some View {
        ShepherdNavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 24)

                    ShepherdEmptyState(
                        icon: "calendar",
                        title: "No meetings yet",
                        message: "Midweek and weekend schedules will show here once your congregation publishes them."
                    )
                    .slideUpEntrance(delay: 0.08)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .background { LiquidMeshBackground() }
            .navigationTitle("Meetings")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
        }
    }
}

#Preview {
    MeetingsView().preferredColorScheme(.dark)
}
