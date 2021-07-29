import UIKit
import Charts

protocol ChartViewProtocol: AnyObject {
    func setChartData(_ data: ChartData)
}

final class ChartView: BarChartView {
    lazy var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        formatter.positivePrefix = "$"
        return formatter
    }()

    let xAxisFormmater = ChartAxisFormmatter()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        chartDescription?.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        dragEnabled = false
        maxVisibleCount = 40
        drawBarShadowEnabled = false
        drawValueAboveBarEnabled = false
        highlightFullBarEnabled = false

        xAxis.gridLineDashLengths = [2.5, 2.5]
        xAxis.gridLineDashPhase = 0
        xAxis.gridColor = UIColor.white.withAlphaComponent(0.64)
        xAxis.labelFont = .p3Paragraph
        xAxis.labelPosition = .bottom
        xAxis.valueFormatter = xAxisFormmater

        leftAxis.labelCount = 2
        leftAxis.valueFormatter = DefaultAxisValueFormatter(formatter: formatter)
        leftAxis.labelFont = .systemFont(ofSize: 8, weight: .semibold)
        leftAxis.labelTextColor = UIColor.white.withAlphaComponent(0.64)
        leftAxis.axisMinimum = 0

        rightAxis.enabled = false
        drawBordersEnabled = false
        minOffset = 0
        legend.enabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChartView: ChartViewProtocol {
    func setChartData(_ data: ChartData) {
        var dataEntries = [BarChartDataEntry]()
        for (index, amount) in data.amounts.enumerated() {
            dataEntries.append(BarChartDataEntry(x: Double(index), yValues: [amount]))
        }

        let set = BarChartDataSet(entries: dataEntries)
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.colors = [
            R.color.colorAccent()!
        ]

        xAxisFormmater.xAxisValues = data.xAxisValues
        xAxis.labelCount = data.xAxisValues.count

        let data = BarChartData(dataSet: set)
        data.barWidth = 0.4

        self.data = data
    }
}

class ChartAxisFormmatter: IAxisValueFormatter {
    var xAxisValues = [String]()

    func stringForValue(_ value: Double, axis _: AxisBase?) -> String {
        xAxisValues[Int(value)]
    }
}
