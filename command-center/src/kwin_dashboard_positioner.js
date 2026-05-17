const TARGET_CAPTION = "Strix Halo Dashboard";
const TARGET_ROLE = "strix-halo-dashboard";
const MARGIN = 8;

function isTarget(window) {
    if (!window || window.deleted || !window.managed) {
        return false;
    }
    return window.windowRole === TARGET_ROLE || window.caption.indexOf(TARGET_CAPTION) === 0;
}

function targetGeometry(window) {
    const screen = window.output || workspace.activeScreen;
    const area = workspace.clientArea(KWin.MaximizeArea, screen);
    const frame = window.frameGeometry;
    return {
        x: area.x + area.width - frame.width - MARGIN,
        y: area.y + area.height - frame.height - MARGIN,
        width: frame.width,
        height: frame.height,
    };
}

function place(window) {
    if (!isTarget(window)) {
        return;
    }

    const current = window.frameGeometry;
    const target = targetGeometry(window);
    const deltaX = Math.abs(current.x - target.x);
    const deltaY = Math.abs(current.y - target.y);
    const deltaW = Math.abs(current.width - target.width);
    const deltaH = Math.abs(current.height - target.height);

    window.keepAbove = true;
    window.skipTaskbar = true;
    window.skipPager = true;

    if (deltaX < 1 && deltaY < 1 && deltaW < 1 && deltaH < 1) {
        return;
    }

    window.frameGeometry = target;
    workspace.raiseWindow(window);
    workspace.activeWindow = window;
}

function manage(window) {
    if (!isTarget(window)) {
        return;
    }

    place(window);
    window.activeChanged.connect(function () {
        if (window.active) {
            place(window);
        }
    });
    window.frameGeometryChanged.connect(function () {
        place(window);
    });
    window.outputChanged.connect(function () {
        place(window);
    });
}

workspace.windowAdded.connect(function (window) {
    manage(window);
});

for (const window of workspace.stackingOrder) {
    manage(window);
}