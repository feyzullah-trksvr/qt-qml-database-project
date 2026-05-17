import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 250
    height: 250
    property var model: []
    property real totalSpent: 0
    property real animProgress: 0

    NumberAnimation on animProgress {
        id: anim
        from: 0
        to: 1.0
        duration: 1000
        easing.type: Easing.OutCubic
    }

    Component.onCompleted: {
        calculateTotal()
        anim.restart()
    }

    onModelChanged: {
        calculateTotal()
        anim.restart()
    }

    function calculateTotal() {
        var t = 0;
        for (var i = 0; i < model.length; i++) {
            t += model[i].amount;
        }
        totalSpent = t;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = Math.min(width, height) / 2 - 45; // reduced radius to fit text with %

            if (root.totalSpent === 0) {
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
                ctx.lineWidth = 15;
                ctx.strokeStyle = "#1E1E24";
                ctx.stroke();
                return;
            }

            var startAngle = -Math.PI / 2;
            for (var i = 0; i < root.model.length; i++) {
                var item = root.model[i];
                var pct = Math.round((item.amount / root.totalSpent) * 100);
                var sliceAngle = (item.amount / root.totalSpent) * 2 * Math.PI * root.animProgress;
                
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle, startAngle + sliceAngle);
                ctx.lineWidth = 15;
                ctx.lineCap = "round"; // Adds rounded ends to the strokes for modern look
                ctx.strokeStyle = item.color;
                ctx.stroke();
                
                // Draw text labels
                var midAngle = startAngle + sliceAngle / 2;
                var textRadius = radius + 25; // outside the circle
                var textX = centerX + textRadius * Math.cos(midAngle);
                var textY = centerY + textRadius * Math.sin(midAngle);
                
                ctx.font = "bold 11px sans-serif";
                ctx.fillStyle = "white";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                ctx.fillText(item.name + " %" + pct, textX, textY);
                
                startAngle += sliceAngle;
            }
            
            // Draw an overlay background ring under it to look nicer
            ctx.globalCompositeOperation = "destination-over";
            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI);
            ctx.lineWidth = 15;
            ctx.strokeStyle = "#1A1A20";
            ctx.stroke();
            ctx.globalCompositeOperation = "source-over";
        }
        
        Connections {
            target: root
            function onAnimProgressChanged() { canvas.requestPaint() }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        Text {
            text: "Harcamalar"
            color: "#888888"
            font.pixelSize: 11
            font.family: "sans-serif"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "₺" + Math.round(root.totalSpent * root.animProgress)
            color: "white"
            font.pixelSize: 22
            font.bold: true
            font.family: "sans-serif"
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
