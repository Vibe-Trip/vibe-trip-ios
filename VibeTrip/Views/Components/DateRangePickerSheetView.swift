//
//  DateRangePickerSheetView.swift
//  VibeTrip
//
//  Created by CHOI on 3/23/26.
//

import SwiftUI

// 여행기간 선택 뷰
struct DateRangePickerSheetView: View {
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    let onConfirm: () -> Void

    @State private var displayedMonth: Date
    // 첫 탭 날짜 anchor 보관
    @State private var anchorDate: Date?

    private let calendar: Calendar

    init(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        onConfirm: @escaping () -> Void
    ) {
        self._startDate = startDate
        self._endDate = endDate
        self.onConfirm = onConfirm

        var configuredCalendar = Calendar(identifier: .gregorian)
        configuredCalendar.locale = Locale(identifier: "ko_KR")
        configuredCalendar.timeZone = .current
        self.calendar = configuredCalendar

        let normalizedStartDate = configuredCalendar.startOfDay(for: startDate.wrappedValue)
        let normalizedEndDate = configuredCalendar.startOfDay(for: endDate.wrappedValue)

        _displayedMonth = State(initialValue: configuredCalendar.startOfMonth(for: normalizedStartDate))
        _anchorDate = State(initialValue: normalizedStartDate == normalizedEndDate ? normalizedStartDate : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("여행 기간")
                .font(.setPretendard(weight: .semiBold, size: 18))
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text("선택한 날짜")
                    .font(.setPretendard(weight: .semiBold, size: 16))
                    .foregroundStyle(Color.textPrimary)

                Text("\(startDate.albumDateString) - \(endDate.albumDateString)")
                    .font(.setPretendard(weight: .medium, size: 14))
                    .foregroundStyle(Color("GrayScale/300"))
            }
            .padding(.leading, 14)

            SwiftUICalendarRangePickerView(
                startDate: $startDate,
                endDate: $endDate,
                displayedMonth: $displayedMonth,
                anchorDate: $anchorDate,
                calendar: calendar
            )

            Button(action: onConfirm) {
                Text("확인")
                    .font(.setPretendard(weight: .semiBold, size: 18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .presentationDetents([.height(590)])
    }
}

private struct SwiftUICalendarRangePickerView: View {

    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var displayedMonth: Date
    @Binding var anchorDate: Date?

    let calendar: Calendar

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 18) {
            monthHeader
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(monthDays.enumerated()), id: \.element.id) { index, item in
                    DayCellView(
                        day: item.day,
                        visualState: visualState(for: item.date, index: index)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let date = item.date else { return }
                        handleDateSelection(date)
                    }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.setPretendard(weight: .semiBold, size: 18))
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.setPretendard(weight: .medium, size: 14))
                    .foregroundStyle(Color("GrayScale/300"))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthDays: [CalendarDayItem] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth)
        else {
            return []
        }

        var items: [CalendarDayItem] = []
        var currentDate = firstWeekInterval.start

        while currentDate < lastWeekInterval.end {
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                // 현재 달 날짜만 표시
                items.append(
                    CalendarDayItem(
                        date: currentDate,
                        day: String(calendar.component(.day, from: currentDate))
                    )
                )
            } else {
                items.append(CalendarDayItem(date: nil, day: ""))
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return items
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        return "\(components.year ?? 0)년 \(components.month ?? 0)월"
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }
        displayedMonth = calendar.startOfMonth(for: nextMonth)
    }

    private func handleDateSelection(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)

        if let anchorDate {
            if normalizedDate < anchorDate {
                self.anchorDate = normalizedDate
                startDate = normalizedDate
                endDate = normalizedDate
                displayedMonth = calendar.startOfMonth(for: normalizedDate)
                return
            }

            startDate = anchorDate
            endDate = normalizedDate
            self.anchorDate = nil
            displayedMonth = calendar.startOfMonth(for: normalizedDate)
            return
        }

        anchorDate = normalizedDate
        startDate = normalizedDate
        endDate = normalizedDate
        displayedMonth = calendar.startOfMonth(for: normalizedDate)
    }

    private func visualState(for date: Date?, index: Int) -> CalendarDayVisualState {
        guard let date else {
            return .empty
        }

        let normalizedDate = calendar.startOfDay(for: date)
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        let isSingleDaySelection = normalizedStartDate == normalizedEndDate && anchorDate != nil
        // 주 시작/끝 칸 연결 여부
        let canConnectLeft = index % 7 != 0
        let canConnectRight = index % 7 != 6

        if isSingleDaySelection && normalizedDate == normalizedStartDate {
            return .singleSelected
        }

        if normalizedDate == normalizedStartDate && normalizedDate == normalizedEndDate {
            return .singleSelected
        }

        if normalizedDate == normalizedStartDate {
            return .rangeStart(connectsRight: canConnectRight)
        }

        if normalizedDate == normalizedEndDate {
            return .rangeEnd(connectsLeft: canConnectLeft)
        }

        if normalizedDate > normalizedStartDate && normalizedDate < normalizedEndDate {
            return .inRange(
                connectsLeft: canConnectLeft,
                connectsRight: canConnectRight
            )
        }

        return .normal
    }
}

private struct DayCellView: View {

    let day: String
    let visualState: CalendarDayVisualState

    private enum Layout {
        static let cellHeight: CGFloat = 44
        static let rangeHeight: CGFloat = 43
        static let circleSize: CGFloat = 43
        static let rangeCornerRadius: CGFloat = 21.5
    }

    var body: some View {
        ZStack {
            rangeBackground

            if visualState.showsSelectedCircle {
                Circle()
                    .fill(Color.appPrimary400)
                    .frame(width: Layout.circleSize, height: Layout.circleSize)
            }

            Text(day)
                .font(.setPretendard(weight: .medium, size: 16))
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.cellHeight)
        .allowsHitTesting(!visualState.isEmpty)
    }

    @ViewBuilder
    private var rangeBackground: some View {
        switch visualState {
        case .rangeStart(let connectsRight):
            HStack(spacing: 0) {
                Color.clear
                rangeFill(leftRounded: false, rightRounded: !connectsRight)
            }
            .frame(height: Layout.rangeHeight)

        case .rangeEnd(let connectsLeft):
            HStack(spacing: 0) {
                rangeFill(leftRounded: !connectsLeft, rightRounded: false)
                Color.clear
            }
            .frame(height: Layout.rangeHeight)

        case .inRange(let connectsLeft, let connectsRight):
            rangeFill(leftRounded: !connectsLeft, rightRounded: !connectsRight)
                .frame(height: Layout.rangeHeight)

        default:
            Color.clear.frame(height: Layout.rangeHeight)
        }
    }

    private var textColor: Color {
        visualState.showsSelectedCircle ? .white : Color.textPrimary
    }

    private func rangeFill(leftRounded: Bool, rightRounded: Bool) -> some View {
        // 좌우 연결 여부 기반 범위 바 모서리 처리
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: leftRounded ? Layout.rangeCornerRadius : 0,
                bottomLeading: leftRounded ? Layout.rangeCornerRadius : 0,
                bottomTrailing: rightRounded ? Layout.rangeCornerRadius : 0,
                topTrailing: rightRounded ? Layout.rangeCornerRadius : 0
            ),
            style: .continuous
        )
        .fill(Color("appPrimary100"))
    }
}

private struct CalendarDayItem: Identifiable {
    let id = UUID()
    let date: Date?
    let day: String
}

private enum CalendarDayVisualState {
    case empty
    case normal
    case singleSelected
    case rangeStart(connectsRight: Bool)
    case inRange(connectsLeft: Bool, connectsRight: Bool)
    case rangeEnd(connectsLeft: Bool)

    var showsSelectedCircle: Bool {
        switch self {
        case .singleSelected, .rangeStart, .rangeEnd:
            return true
        default:
            return false
        }
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        guard let month = self.date(from: dateComponents([.year, .month], from: date)) else {
            return startOfDay(for: date)
        }
        return startOfDay(for: month)
    }
}

#Preview {
    DateRangePickerSheetView(
        startDate: .constant(Date()),
        endDate: .constant(Date().addingTimeInterval(86_400 * 6)),
        onConfirm: {}
    )
}
