//
//  DateRangePickerSheetView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI
import UIKit

// 여행기간 선택 뷰
struct DateRangePickerSheetView: View {
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    let onConfirm: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("여행기간")
                        .font(Font.setPretendard(weight: .semiBold, size: 16))
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("\(startDate.albumDateString) - \(endDate.albumDateString)")
                        .font(Font.setPretendard(weight: .medium, size: 14))
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(.horizontal, 12)
                
                CalendarRangePickerView(
                    startDate: $startDate,
                    endDate: $endDate
                )
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                
                Button(action: onConfirm) {
                    Text("확인")
                        .font(Font.setPretendard(weight: .semiBold, size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.appPrimary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .navigationTitle("여행기간 선택")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(560)])
    }
}

private struct CalendarRangePickerView: UIViewRepresentable {
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = .current
        
        calendarView.calendar = calendar
        calendarView.locale = Locale(identifier: "ko_KR")
        calendarView.tintColor = UIColor(named: "appPrimary") ?? .systemBlue
        calendarView.availableDateRange = DateInterval(start: .distantPast, end: .distantFuture)
        
        let selection = UICalendarSelectionMultiDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        context.coordinator.selection = selection
        context.coordinator.applySelection(animated: false)
        
        return calendarView
    }
    
    // SwiftUI 상태가 바뀌면 UIKit 캘린더 선택 상태를 다시 동기화한다.
    func updateUIView(_ uiView: UICalendarView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applySelection(animated: false)
        uiView.visibleDateComponents = context.coordinator.dateComponents(for: startDate)
    }
    
    final class Coordinator: NSObject, UICalendarSelectionMultiDateDelegate {
        
        var parent: CalendarRangePickerView
        weak var selection: UICalendarSelectionMultiDate?
        private let calendar = Calendar(identifier: .gregorian)
        private var isProgrammaticSelection = false
        private var anchorDate: Date?
        
        init(parent: CalendarRangePickerView) {
            self.parent = parent
            self.anchorDate = calendar.startOfDay(for: parent.startDate)
        }
        
        // 시작일(첫 선택) 및 종료일(마지막 선택) 구별
        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
            guard !isProgrammaticSelection,
                  let selectedDate = calendar.date(from: dateComponents) else {
                return
            }
            
            let normalizedDate = calendar.startOfDay(for: selectedDate)
            
            if let anchorDate {
                if normalizedDate < anchorDate {
                    self.anchorDate = normalizedDate
                    parent.startDate = normalizedDate
                    parent.endDate = normalizedDate
                    applySelection(animated: true)
                    return
                }
                
                parent.startDate = anchorDate
                parent.endDate = normalizedDate
                self.anchorDate = nil
                applySelection(animated: true)
                return
            }
            
            anchorDate = normalizedDate
            parent.startDate = normalizedDate
            parent.endDate = normalizedDate
            applySelection(animated: true)
        }
        
        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
            applySelection(animated: false)
        }
        
        func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canDeselectDate dateComponents: DateComponents) -> Bool {
            false
        }
        
        // 시작일 및 종료일 범위 표시
        func applySelection(animated: Bool) {
            guard let selection else {
                return
            }
            
            isProgrammaticSelection = true
            selection.setSelectedDates(selectedDateComponents, animated: animated)
            isProgrammaticSelection = false
        }
        
        // DateComponents 형식
        func dateComponents(for date: Date) -> DateComponents {
            calendar.dateComponents([.calendar, .era, .year, .month, .day], from: calendar.startOfDay(for: date))
        }
        
        // 시작일 및 종료일 범위 표시
        private var selectedDateComponents: [DateComponents] {
            let normalizedStartDate = calendar.startOfDay(for: parent.startDate)
            let normalizedEndDate = calendar.startOfDay(for: parent.endDate)
            
            guard normalizedStartDate <= normalizedEndDate else {
                return [dateComponents(for: normalizedStartDate)]
            }
            
            var components: [DateComponents] = []
            var currentDate = normalizedStartDate
            
            while currentDate <= normalizedEndDate {
                components.append(dateComponents(for: currentDate))
                
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                    break
                }
                
                currentDate = nextDate
            }
            
            return components
        }
    }
}

#Preview {
    DateRangePickerSheetView(
        startDate: .constant(Date()),
        endDate: .constant(Date().addingTimeInterval(86_400)),
        onConfirm: {}
    )
}
