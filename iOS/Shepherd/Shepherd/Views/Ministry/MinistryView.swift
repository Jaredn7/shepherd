//
//  MinistryView.swift
//  Shepherd
//

import SwiftUI

struct MinistryView: View {
    var body: some View {
        ShepherdNavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 24)

                    ShepherdEmptyState(
                        icon: "book.closed.fill",
                        title: "No ministry records yet",
                        message: "Your field service reports, hours, and territories will appear here once you start reporting."
                    )
                    .slideUpEntrance(delay: 0.08)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .background { LiquidMeshBackground() }
            .navigationTitle("Ministry")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
        }
    }
}

#Preview {
    MinistryView().preferredColorScheme(.dark)
}
