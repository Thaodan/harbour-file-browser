import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: base
    anchors.fill: parent
    property real radius: 0.8*(Theme.iconSizeMedium/2)
    property var image

    Canvas {
        id: frame
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.2);
            ctx.fillRect((image.width  - image.paintedWidth) /2,
                         (image.height - image.paintedHeight)/2,
                         image.paintedWidth, image.paintedHeight)
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0);
            ctx.globalCompositeOperation = "copy"
            ctx.strokeStyle = Theme.highlightColor
            ctx.beginPath()
            ctx.moveTo(topLeft.center.x, topLeft.center.y)
            ctx.lineTo(topRight.center.x, topRight.center.y)
            ctx.lineTo(bottomRight.center.x, bottomRight.center.y)
            ctx.lineTo(bottomLeft.center.x, bottomLeft.center.y)
            ctx.closePath()
            ctx.fill()
            ctx.stroke()
        }
    }

    transform: Rotation {
        origin: image.imageRotation.origin
        angle: image.imageRotation.angle
        onAngleChanged: frame.requestPaint();
    }

    function updateCenterMarkers(skip) {
        if (skip !== "horizontal") {
            topCenter.x = Math.min(topLeft.x, topRight.x)+Math.abs(topLeft.x-topRight.x)/2
            topCenter.y = topLeft.y;
            bottomCenter.x = Math.min(bottomLeft.x, bottomRight.x)+Math.abs(bottomLeft.x-bottomRight.x)/2;
            bottomCenter.y = bottomLeft.y;
        }
        if (skip !== "vertical") {
            leftCenter.y = Math.min(bottomLeft.y, topLeft.y)+Math.abs(bottomLeft.y-topLeft.y)/2;
            leftCenter.x = topLeft.x;
            rightCenter.y = Math.min(bottomRight.y, topRight.y)+Math.abs(bottomRight.y-topRight.y)/2;
            rightCenter.x = topRight.x;
        }
    }

    function reset() {
        topLeft.reset(); topCenter.reset(); topRight.reset();
        leftCenter.reset(); rightCenter.reset();
        bottomLeft.reset(); bottomCenter.reset(); bottomRight.reset();
        frame.requestPaint();
    }

    CropMarker {
        id: topLeft
        radius: parent.radius
        initialCenterX: (image.width - image.paintedWidth) / 2 + radius
        initialCenterY: (image.height - image.paintedHeight) / 2 + radius
        minX: (image.width - image.paintedWidth) / 2
        maxX: (image.width + image.paintedWidth) / 2 - 2*radius
        minY: (image.height - image.paintedHeight) / 2
        maxY: (image.height + image.paintedHeight) / 2 - 2*radius
        onCenterChanged: {
            if (!dragActive) return;
            bottomLeft.x = x; topRight.y = y;
            updateCenterMarkers();
            frame.requestPaint();
        }
    }

    CropMarker {
        id: topRight
        radius: parent.radius
        initialCenterX: (image.width  + image.paintedWidth) / 2 - radius
        initialCenterY: (image.height - image.paintedHeight) / 2 + radius
        minX: (image.width - image.paintedWidth) / 2
        maxX: (image.width + image.paintedWidth) / 2 - 2*radius
        minY: (image.height - image.paintedHeight) / 2
        maxY: (image.height + image.paintedHeight) / 2 - 2*radius
        onCenterChanged: {
            if (!dragActive) return;
            bottomRight.x = x; topLeft.y = y;
            updateCenterMarkers();
            frame.requestPaint();
        }

    }

    CropMarker {
        id: bottomLeft
        radius: parent.radius
        initialCenterX: (image.width  - image.paintedWidth) / 2 + radius
        initialCenterY: (image.height + image.paintedHeight) / 2 - radius
        minX: (image.width - image.paintedWidth) / 2
        maxX: (image.width + image.paintedWidth) / 2 - 2*radius
        minY: (image.height - image.paintedHeight) / 2
        maxY: (image.height + image.paintedHeight) / 2 - 2*radius
        onCenterChanged: {
            if (!dragActive) return;
            topLeft.x = x; bottomRight.y = y;
            updateCenterMarkers();
            frame.requestPaint();
        }

    }

    CropMarker {
        id: bottomRight
        radius: parent.radius
        initialCenterX: (image.width  + image.paintedWidth) / 2 - radius
        initialCenterY: (image.height + image.paintedHeight) / 2 - radius
        minX: (image.width - image.paintedWidth) / 2
        maxX: (image.width + image.paintedWidth) / 2 - 2*radius
        minY: (image.height - image.paintedHeight) / 2
        maxY: (image.height + image.paintedHeight) / 2 - 2*radius
        onCenterChanged: {
            if (!dragActive) return;
            topRight.x = x; bottomLeft.y = y;
            updateCenterMarkers();
            frame.requestPaint();
        }
    }

    CropMarker {
        id: topCenter
        radius: parent.radius
        beVCenter: true
        initialCenterX: image.width/2
        initialCenterY: (image.height - image.paintedHeight) / 2 + radius
        minX: Math.min(topLeft.x, topRight.x)+Math.abs(topLeft.x-topRight.x)/2 + 2*radius
        maxX: minX
        minY: (image.height - image.paintedHeight) / 2
        maxY: (image.height + image.paintedHeight) / 2 - 2*radius
        onCenterChanged: {
            if (!dragActive) return;
            topLeft.y = y; topRight.y = y;
            updateCenterMarkers("horizontal");
            frame.requestPaint();
        }
    }

    CropMarker {
        id: bottomCenter
        radius: parent.radius
        beVCenter: true
        initialCenterX: image.width/2
        initialCenterY: (image.height + image.paintedHeight) / 2 - radius
        minX: Math.min(bottomLeft.x, bottomRight.x)+Math.abs(bottomLeft.x-bottomRight.x)/2 + 2*radius
        maxX: minX
        minY: (image.height - image.paintedHeight) / 2
        maxY: (image.height + image.paintedHeight) / 2 - 2*radius
        onCenterChanged: {
            if (!dragActive) return;
            bottomLeft.y = y; bottomRight.y = y;
            updateCenterMarkers("horizontal");
            frame.requestPaint();
        }
    }

    CropMarker {
        id: leftCenter
        radius: parent.radius
        beHCenter: true
        initialCenterX: (image.width  - image.paintedWidth) / 2 + radius
        initialCenterY: image.height/2
        minX: (image.width - image.paintedWidth) / 2
        maxX: (image.width + image.paintedWidth) / 2 - 2*radius
        minY: Math.min(bottomLeft.y, topLeft.y)+Math.abs(bottomLeft.y-topLeft.y)/2 + 2*radius
        maxY: minY
        onCenterChanged: {
            if (!dragActive) return;
            bottomLeft.x = x; topLeft.x = x;
            updateCenterMarkers("vertical");
            frame.requestPaint();
        }
    }

    CropMarker {
        id: rightCenter
        radius: parent.radius
        beHCenter: true
        initialCenterX: (image.width  + image.paintedWidth) / 2 - radius
        initialCenterY: image.height/2
        minX: (image.width - image.paintedWidth) / 2
        maxX: (image.width + image.paintedWidth) / 2 - 2*radius
        minY: Math.min(bottomRight.y, topRight.y)+Math.abs(bottomRight.y-topRight.y)/2 + 2*radius
        maxY: minY
        onCenterChanged: {
            if (!dragActive) return;
            bottomRight.x = x; topRight.x = x;
            updateCenterMarkers("vertical");
            frame.requestPaint();
        }
    }
}
