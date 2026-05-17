import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: window
    width: 400
    height: 850
    visible: true
    title: qsTr("Ev Bütçem")
    color: "#0B0C10"

    property real totalIncome: 0
    property real totalExpense: 0
    property var chartData: []
    property var allExpensesData: []
    
    property int passedDays: 0
    property string currentDayName: ""
    property bool chartVisible: true

    // New Properties for Filtering
    property int weekOffset: 0
    property int selectedDayIndex: -1
    property bool isMonthlyMode: false

    property int editingExpenseId: -1
    property string editingExpenseDateStr: ""
    property int deletingExpenseId: -1

    function formatSqlDate(date, isEnd) {
        var y = date.getFullYear();
        var m = (date.getMonth() + 1).toString().padStart(2, '0');
        var d = date.getDate().toString().padStart(2, '0');
        var time = isEnd ? "23:59:59" : "00:00:00";
        return y + "-" + m + "-" + d + " " + time;
    }

    function calculateDates() {
        var now = new Date();
        var day = now.getDay();
        var daysTR = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];
        currentDayName = daysTR[day];
        passedDays = (day === 6) ? 0 : (day + 1);

        var diffToLastSat = (day === 6) ? 0 : (day + 1);
        var currentWeekSat = new Date(now.getFullYear(), now.getMonth(), now.getDate() - diffToLastSat);
        
        var startStr = "";
        var endStr = "";
        
        if (isMonthlyMode) {
            var firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
            var lastDayOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);
            startStr = formatSqlDate(firstDayOfMonth, false);
            endStr = formatSqlDate(lastDayOfMonth, true);
        } else {
            var targetSat = new Date(currentWeekSat);
            targetSat.setDate(currentWeekSat.getDate() + (weekOffset * 7));
            
            if (selectedDayIndex !== -1) {
                var specificDay = new Date(targetSat);
                specificDay.setDate(targetSat.getDate() + selectedDayIndex);
                startStr = formatSqlDate(specificDay, false);
                endStr = formatSqlDate(specificDay, true);
            } else {
                var targetFri = new Date(targetSat);
                targetFri.setDate(targetSat.getDate() + 6);
                startStr = formatSqlDate(targetSat, false);
                endStr = formatSqlDate(targetFri, true);
            }
        }
        return { start: startStr, end: endStr };
    }

    function formatFriendlyDate(dateStr) {
        if (!dateStr) return "";
        var parts = dateStr.split(" ");
        if (parts.length < 2) return dateStr;
        var dParts = parts[0].split("-");
        if (dParts.length < 3) return dateStr;
        
        var year = parseInt(dParts[0]);
        var month = parseInt(dParts[1]) - 1;
        var day = parseInt(dParts[2]);
        var d = new Date(year, month, day);
        
        var monthsTR = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
        var daysTR = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];
        
        return day + " " + monthsTR[month] + " " + daysTR[d.getDay()];
    }

    function refreshData() {
        var range = calculateDates();
        
        totalIncome = dbManager.getTotalIncome(range.start, range.end);
        totalExpense = dbManager.getTotalExpenses(range.start, range.end);
        chartData = dbManager.getCategorySummary(range.start, range.end);
        
        allExpensesData = dbManager.getExpenses(range.start, range.end);
        listModel.clear();
        for (var i = 0; i < allExpensesData.length; i++) {
            listModel.append(allExpensesData[i]);
        }
    }

    Component.onCompleted: {
        refreshData()
    }

    ListModel { id: listModel }
    ListModel { id: subItemsModel } // For dynamic expense items

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            ColumnLayout {
                spacing: 0
                Text {
                    text: isMonthlyMode ? "Aylık Kalan Bakiye" : "Kalan Bakiye"
                    color: "#888888"
                    font.pixelSize: 12
                    font.family: "sans-serif"
                }
                Text {
                    text: "₺" + (totalIncome - totalExpense).toFixed(2)
                    color: (totalIncome - totalExpense) >= 0 ? "white" : "#FF3366"
                    font.pixelSize: 28
                    font.bold: true
                    font.family: "sans-serif"
                }
            }
            Item { Layout.fillWidth: true }
            
            Rectangle {
                width: 36
                height: 36
                radius: 10
                color: Qt.rgba(0, 230, 118, 0.15)
                Text {
                    anchors.centerIn: parent
                    text: "+"
                    color: "#00E676"
                    font.pixelSize: 20
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: incomePopup.open()
                }
            }
        }
        
        // Progress Bar & History Controls
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            visible: !isMonthlyMode
            spacing: 4
            
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    width: 24; height: 24; radius: 12; color: "#1E1E24"
                    Text { anchors.centerIn: parent; text: "◀"; color: "white"; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: { weekOffset--; refreshData(); } }
                }
                Text { 
                    text: weekOffset === 0 ? "Bu Hafta" : (weekOffset === -1 ? "Geçen Hafta" : Math.abs(weekOffset) + " Hafta Önce")
                    color: "#FFFFFF"; font.pixelSize: 12; font.bold: true
                }
                Rectangle {
                    width: 24; height: 24; radius: 12; color: weekOffset < 0 ? "#1E1E24" : "transparent"
                    visible: weekOffset < 0
                    Text { anchors.centerIn: parent; text: "▶"; color: "white"; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; onClicked: { if(weekOffset < 0) { weekOffset++; refreshData(); } } }
                }
                
                Item { Layout.fillWidth: true }
                
                Text { 
                    text: selectedDayIndex !== -1 ? "Seçili Gün" : ("Bugün: " + currentDayName)
                    color: selectedDayIndex !== -1 ? "#FA709A" : "#00F2FE"
                    font.pixelSize: 11; font.bold: true 
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                height: 25 
                spacing: 4
                
                Repeater {
                    model: ["Cts", "Paz", "Pzt", "Sal", "Çar", "Per", "Cum"]
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: modelData
                            color: selectedDayIndex === index ? "#FA709A" : "#666666"
                            font.pixelSize: 9
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 4
                            radius: 2
                            color: selectedDayIndex === index ? "#FA709A" : (weekOffset < 0 || index <= passedDays ? "#00F2FE" : "#1E1E24")
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -10 
                                onClicked: {
                                    if (selectedDayIndex === index) selectedDayIndex = -1; 
                                    else selectedDayIndex = index;
                                    refreshData();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Chart Header
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 5
            Text {
                text: isMonthlyMode ? "Aylık Özeti (Kaydır)" : "Haftalık Özeti (Kaydır)"
                color: "white"
                font.pixelSize: 14
                font.bold: true
                font.family: "sans-serif"
                Layout.fillWidth: true
            }
            Text {
                text: chartVisible ? "Gizle ▲" : "Göster ▼"
                color: "#888888"
                font.pixelSize: 11
                MouseArea { anchors.fill: parent; onClicked: chartVisible = !chartVisible }
            }
        }

        // Swipeable Circular Chart
        Item {
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredWidth: 200
            Layout.preferredHeight: chartVisible ? 200 : 0
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            
            SwipeView {
                id: chartSwipe
                anchors.fill: parent
                currentIndex: isMonthlyMode ? 1 : 0
                interactive: true 
                
                onCurrentIndexChanged: {
                    var newMode = (currentIndex === 1);
                    if (isMonthlyMode !== newMode) {
                        isMonthlyMode = newMode;
                        selectedDayIndex = -1;
                        refreshData();
                    }
                }
                
                Item {
                    RingChart { anchors.centerIn: parent; width: 200; height: 200; model: isMonthlyMode ? [] : chartData }
                    Text { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: "Haftalık"; color: "#666"; font.pixelSize: 10 }
                }
                Item {
                    RingChart { anchors.centerIn: parent; width: 200; height: 200; model: isMonthlyMode ? chartData : [] }
                    Text { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: "Aylık"; color: "#666"; font.pixelSize: 10 }
                }
            }
        }

        // Add Expense Button
        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            height: 50
            radius: 12
            color: "#16161E"
            RowLayout {
                anchors.centerIn: parent
                spacing: 10
                Rectangle {
                    width: 24; height: 24; radius: 12; color: Qt.rgba(255, 51, 102, 0.15)
                    Text { anchors.centerIn: parent; text: "↑"; color: "#FF3366"; font.pixelSize: 14; font.bold: true }
                }
                Text { text: "Yeni Gider Ekle"; color: "white"; font.pixelSize: 13; font.bold: true; font.family: "sans-serif" }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    editingExpenseId = -1
                    editingExpenseDateStr = ""
                    titleInput.text = ""
                    categoryCombo.currentIndex = 0
                    subItemsModel.clear()
                    subItemsModel.append({itemName: "", itemAmount: ""})
                    expensePopup.open()
                }
            }
        }

        // Transactions List
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true 
            spacing: 8
            
            Text {
                text: selectedDayIndex !== -1 ? "Seçili Günün Harcamaları" : "Tüm Harcamalar"
                color: "white"
                font.pixelSize: 14
                font.bold: true
                font.family: "sans-serif"
                Layout.fillWidth: true
                Layout.topMargin: 5
            }

            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: listModel
                spacing: 8
                clip: true
                
                delegate: Rectangle {
                    width: listView.width
                    height: contentCol.height + 20 // Dynamic height based on subitems
                    radius: 12
                    color: "#16161E"
                    
                    ColumnLayout {
                        id: contentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 6
                        
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            
                            Rectangle {
                                width: 36
                                height: 36
                                radius: 10
                                property color myColor: model.color
                                color: Qt.rgba(myColor.r, myColor.g, myColor.b, 0.15)
                                Layout.alignment: Qt.AlignTop
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (model.category === "Market") return "🛒";
                                        if (model.category === "Yakıt") return "⛽";
                                        if (model.category === "Sağlık") return "💊";
                                        if (model.category === "Fatura") return "📄";
                                        if (model.category === "Eğlence") return "🎬";
                                        return "📦";
                                    }
                                    font.pixelSize: 16
                                }
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.name
                                        color: "white"
                                        font.pixelSize: 14
                                        font.bold: true
                                        font.family: "sans-serif"
                                        wrapMode: Text.Wrap
                                    }
                                }
                                RowLayout {
                                    Rectangle {
                                        radius: 3
                                        color: "#2A2A35"
                                        height: 14
                                        width: catText.width + 8
                                        Text {
                                            id: catText
                                            anchors.centerIn: parent
                                            text: model.category
                                            color: "#BBBBBB"
                                            font.pixelSize: 8
                                        }
                                    }
                                    Text {
                                        text: formatFriendlyDate(model.date)
                                        color: "#666666"
                                        font.pixelSize: 10
                                        font.family: "sans-serif"
                                    }
                                }
                                
                                // Subitems repeater
                                Item { Layout.preferredHeight: 2; visible: model.subitems !== "" } // space
                                Repeater {
                                    model: model.subitems && model.subitems !== "" ? JSON.parse(model.subitems) : []
                                    Text {
                                        text: "• " + modelData.name + ": ₺" + parseFloat(modelData.amount).toFixed(2)
                                        color: "#AAAAAA"
                                        font.pixelSize: 11
                                        font.family: "sans-serif"
                                    }
                                }
                            }
                            
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 8
                                Text {
                                    text: "-₺" + model.amount.toFixed(2)
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "sans-serif"
                                    Layout.alignment: Qt.AlignRight
                                }
                                RowLayout {
                                    spacing: 10
                                    Layout.alignment: Qt.AlignRight
                                    Rectangle {
                                        width: 26; height: 26; radius: 6; color: "#2A2A35"
                                        Text { anchors.centerIn: parent; text: "✏️"; font.pixelSize: 11 }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                editingExpenseId = model.id
                                                editingExpenseDateStr = model.date
                                                titleInput.text = ""
                                                
                                                subItemsModel.clear()
                                                if (model.subitems && model.subitems !== "") {
                                                    titleInput.text = model.name
                                                    var subs = JSON.parse(model.subitems)
                                                    for(var i=0; i<subs.length; i++) {
                                                        subItemsModel.append({itemName: subs[i].name, itemAmount: subs[i].amount.toString()})
                                                    }
                                                } else {
                                                    subItemsModel.append({itemName: model.name, itemAmount: model.amount.toString()})
                                                }
                                                
                                                var cats = ["Market", "Yakıt", "Sağlık", "Fatura", "Eğlence", "Diğer"]
                                                var idx = cats.indexOf(model.category)
                                                categoryCombo.currentIndex = idx >= 0 ? idx : 0
                                                expensePopup.open()
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: 26; height: 26; radius: 6; color: Qt.rgba(255, 51, 102, 0.15)
                                        Text { anchors.centerIn: parent; text: "🗑️"; font.pixelSize: 11 }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                deletingExpenseId = model.id
                                                deleteConfirmPopup.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- POPUPS ---

    Popup {
        id: deleteConfirmPopup
        width: 280
        height: 150
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        focus: true
        background: Rectangle { color: "#F0F0F0"; radius: 15 }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            Text { text: "Emin Misiniz?"; color: "#111111"; font.pixelSize: 16; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text { text: "Bu harcama kalıcı olarak silinecek."; color: "#666666"; font.pixelSize: 13; Layout.alignment: Qt.AlignHCenter }
            RowLayout {
                Layout.fillWidth: true
                spacing: 15
                Button {
                    text: "İptal"
                    Layout.fillWidth: true
                    onClicked: deleteConfirmPopup.close()
                }
                Button {
                    text: "Sil"
                    Layout.fillWidth: true
                    background: Rectangle { color: "#FF3366"; radius: 5 }
                    contentItem: Text { text: "Sil"; color: "white"; horizontalAlignment: Text.AlignHCenter; font.bold: true }
                    onClicked: {
                        if (deletingExpenseId !== -1) {
                            dbManager.deleteExpense(deletingExpenseId);
                            refreshData();
                        }
                        deleteConfirmPopup.close();
                    }
                }
            }
        }
    }

    Popup {
        id: incomePopup
        width: 300
        height: 200
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        focus: true
        background: Rectangle { color: "#F0F0F0"; radius: 20 }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            Text { text: "Bakiye Ekle"; color: "#111111"; font.pixelSize: 18; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            TextField {
                id: incomeAmountInput
                Layout.fillWidth: true
                placeholderText: "Tutar (Örn: 12000)"
                color: "black"
                font.pixelSize: 16
                background: Rectangle { color: "white"; radius: 10; border.color: "#DDDDDD"; border.width: 1 }
                validator: DoubleValidator { bottom: 0 }
                inputMethodHints: Qt.ImhFormattedNumbersOnly
            }
            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: "İptal"
                    Layout.fillWidth: true
                    onClicked: incomePopup.close()
                }
                Button {
                    text: "Kaydet"
                    Layout.fillWidth: true
                    onClicked: {
                        if (incomeAmountInput.text.length > 0) {
                            var dateStr = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm:ss");
                            dbManager.addIncome(parseFloat(incomeAmountInput.text), dateStr);
                            incomeAmountInput.text = "";
                            refreshData();
                            incomePopup.close();
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: expensePopup
        width: 340
        height: 500
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        focus: true
        background: Rectangle { color: "#F0F0F0"; radius: 20 }
        
        ScrollView {
            anchors.fill: parent
            contentWidth: availableWidth
            clip: true
            
            ColumnLayout {
                width: parent.width
                anchors.margins: 20
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 20
                spacing: 15
                
                Text { text: editingExpenseId !== -1 ? "Gider Düzenle" : "Gider Ekle"; color: "#111111"; font.pixelSize: 18; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                
                Text {
                    visible: editingExpenseId !== -1
                    text: "Kayıt Tarihi: " + editingExpenseDateStr
                    color: "#666666"; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter
                }

                ComboBox {
                    id: categoryCombo
                    Layout.fillWidth: true
                    model: ["Market", "Yakıt", "Sağlık", "Fatura", "Eğlence", "Diğer"]
                }
                
                TextField {
                    id: titleInput
                    Layout.fillWidth: true
                    placeholderText: "Fiş/Fatura Başlığı (Opsiyonel)"
                    placeholderTextColor: "#888888"
                    color: "black"; font.pixelSize: 14
                    background: Rectangle { color: "white"; radius: 10; border.color: "#DDDDDD"; border.width: 1 }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 5
                    Text { text: "Harcama Kalemleri"; color: "#111"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true }
                    Rectangle {
                        width: 24; height: 24; radius: 12; color: "#00E676"
                        Text { text: "+"; color: "white"; font.bold: true; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; onClicked: subItemsModel.append({itemName: "", itemAmount: ""}) }
                    }
                }
                
                Repeater {
                    model: subItemsModel
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Kalem Adı"
                            text: model.itemName
                            color: "black"; font.pixelSize: 14
                            background: Rectangle { color: "white"; radius: 8; border.color: "#DDDDDD"; border.width: 1 }
                            onTextChanged: model.itemName = text
                        }
                        TextField {
                            Layout.preferredWidth: 80
                            placeholderText: "Tutar"
                            text: model.itemAmount
                            color: "black"; font.pixelSize: 14
                            background: Rectangle { color: "white"; radius: 8; border.color: "#DDDDDD"; border.width: 1 }
                            onTextChanged: model.itemAmount = text
                            validator: DoubleValidator { bottom: 0 }
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                        Rectangle {
                            width: 24; height: 24; radius: 6; color: "#FF3366"
                            visible: subItemsModel.count > 1
                            Text { text: "X"; color: "white"; font.bold: true; anchors.centerIn: parent }
                            MouseArea { anchors.fill: parent; onClicked: subItemsModel.remove(index) }
                        }
                    }
                }
                
                Item { Layout.preferredHeight: 10 } // Spacer
                
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "İptal"
                        Layout.fillWidth: true
                        onClicked: expensePopup.close()
                    }
                    Button {
                        text: "Kaydet"
                        Layout.fillWidth: true
                        onClicked: {
                            var totalAmount = 0;
                            var subArray = [];
                            var firstItemName = "";

                            for(var i=0; i<subItemsModel.count; i++) {
                                var itm = subItemsModel.get(i);
                                // replace comma with dot for parsing
                                var amtStr = itm.itemAmount.replace(",", ".");
                                var amt = parseFloat(amtStr);
                                if(isNaN(amt)) amt = 0;
                                
                                if(amt > 0) {
                                    totalAmount += amt;
                                    var n = itm.itemName.trim() === "" ? "İsimsiz" : itm.itemName.trim();
                                    if(i === 0) firstItemName = n;
                                    subArray.push({name: n, amount: amt});
                                }
                            }

                            if (totalAmount <= 0) return;

                            var finalTitle = titleInput.text.trim();
                            if (finalTitle === "") {
                                if (subArray.length === 1) finalTitle = firstItemName;
                                else finalTitle = categoryCombo.currentText + " Alışverişi";
                            }

                            var subItemsJson = (subArray.length > 1) ? JSON.stringify(subArray) : "";
                            var colors = ["#00F2FE", "#FA709A", "#00E676", "#FEE140", "#B224EF", "#AAAAAA"];
                            var color = colors[categoryCombo.currentIndex];
                            var dateStr = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm:ss");

                            if (editingExpenseId !== -1) {
                                dbManager.updateExpense(editingExpenseId, categoryCombo.currentText, finalTitle, totalAmount, color, subItemsJson);
                            } else {
                                dbManager.addExpense(categoryCombo.currentText, finalTitle, totalAmount, dateStr, color, subItemsJson);
                            }

                            refreshData();
                            expensePopup.close();
                        }
                    }
                }
            }
        }
    }
}
