//
//  ChartView.swift
//  AutotradingMac
//

import SwiftUI

struct ChartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart")
                .font(.title3.bold())
            Text("종목 선택 후 차트/상세 정보가 들어올 자리입니다.")
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary.opacity(0.25))
                .frame(minHeight: 320)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Chart Placeholder")
                            .foregroundStyle(.secondary)
                    }
                )
        }
        .padding()
        .navigationTitle("Chart")
    }
}
