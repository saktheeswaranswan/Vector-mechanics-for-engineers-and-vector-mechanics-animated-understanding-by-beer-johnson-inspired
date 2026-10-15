
/*
 MECHANICS VECTORS FOR ENGINEERS
 OPTIMIZED MULTI-OBSERVER + RANDOM PARAMETRIC AXIS MOTION
 Processing Java Mode / Android Mode
 SINGLE-FILE VERSION

 FEATURES
 1. Twelve selectable animated entities
 2. Eight independent observer axes
 3. Fixed, entity-following and random-path axes
 4. Grid-snapped origin placement and dragging
 5. Cached grid points inside entity shapes
 6. Dynamic position, component and resultant vectors
 7. Relative velocity for each observer
 8. All-point vector toggles
 9. Cell-size and object-scale controls
10. Touch-friendly 30-button panel
11. Throttle, brake, pause, reset and telemetry
12. Straight-line/free-motion toggle
13. Independent axis visibility
14. Add, select and delete axes
15. Random parametric path assignment per selected axis
16. Bounded paths; origins stay above the control panel
17. Grid-point generation is cached instead of rebuilt every frame

 COORDINATES
 +X right; +Y upward.
 Screen Y increases downward.
 Position: metres. Velocity: metres/second.
*/

final int MAX_OBSERVERS = 8;
final int ENTITY_COUNT = 12;
final int BUTTON_COUNT = 30;
final int BUTTON_COLS = 6;
final int BUTTON_ROWS = 5;
final int MAX_POINTS = 1200;

final float PIXELS_PER_METRE = 16.0;
final float GRID_SPACING = 50.0;
final float MIN_CELL_SIZE = 6.0;
final float MAX_CELL_SIZE = 30.0;

float speedKmh = 0;
float throttle = 0.35;
float worldDistance = 0;
float elapsedTime = 0;
float objectTravelX = 0;
float animationTime = 0;

float objectScale = 1.5;
float cellSize = 12;

float entityX, entityY, initialEntityX;
float roadY, roadHeight;
float entityVX, entityVY;
float previousEntityY;

boolean paused = false;
boolean straightLineMode = false;

boolean showWorldGrid = true;
boolean showCells = true;
boolean showPosition = true;
boolean showVelocity = true;
boolean showRelative = true;
boolean showCoordinates = true;
boolean showLabels = true;
boolean snapToGrid = true;

boolean showAllPointVelocities = false;
boolean showAllPositionVectors = false;
boolean showAllPointVelocityAxes = false;
boolean showAllResultantVectors = false;

boolean draggingSlider = false;
boolean draggingAxis = false;
boolean placingOrigin = false;

int currentEntity = 2;
int observerCount = 1;
int selectedObserver = 0;
int selectedPoint = 0;
int pointCount = 0;

float[] pointLocalX = new float[MAX_POINTS];
float[] pointLocalY = new float[MAX_POINTS];

int skyColor, roadColor;
PFont uiFont;

String[] entityNames = {
  "MAN", "SCOOTER", "BICYCLE", "BULLOCK CART",
  "LORRY", "CAR", "AEROPLANE", "BIRD",
  "SNAIL", "TORTOISE", "LEOPARD", "ELEPHANT"
};

float[] maxSpeeds = {
  15, 90, 30, 15, 120, 180,
  900, 60, 1, 3, 110, 40
};

float[] observerX = new float[MAX_OBSERVERS];
float[] observerY = new float[MAX_OBSERVERS];
float[] observerVX = new float[MAX_OBSERVERS];
float[] observerVY = new float[MAX_OBSERVERS];

boolean[] observerFollows = new boolean[MAX_OBSERVERS];
boolean[] observerVisible = new boolean[MAX_OBSERVERS];
boolean[] randomPath = new boolean[MAX_OBSERVERS];

String[] observerNames = new String[MAX_OBSERVERS];

// Parametric path parameters for each observer.
int[] pathType = new int[MAX_OBSERVERS];
float[] pathCenterX = new float[MAX_OBSERVERS];
float[] pathCenterY = new float[MAX_OBSERVERS];
float[] pathAmplitudeX = new float[MAX_OBSERVERS];
float[] pathAmplitudeY = new float[MAX_OBSERVERS];
float[] pathOmegaX = new float[MAX_OBSERVERS];
float[] pathOmegaY = new float[MAX_OBSERVERS];
float[] pathPhaseX = new float[MAX_OBSERVERS];
float[] pathPhaseY = new float[MAX_OBSERVERS];

int[] observerColors = {
  0xFF00A6FF, 0xFFFF4040,
  0xFF20C878, 0xFFFFA020,
  0xFFB070FF, 0xFFFF55AA,
  0xFF20D0D0, 0xFFFFFF60
};

// Cache invalidation: rebuild only when geometry changes.
boolean pointsDirty = true;
int cachedEntity = -1;
float cachedCellSize = -1;
float cachedScale = -1;

// ============================================================
// INITIALIZATION
// ============================================================

void settings() {
  fullScreen();
}

void setup() {
  orientation(LANDSCAPE);
  frameRate(30);
  smooth(2);

  uiFont = createFont("sans-serif", 16, true);
  textFont(uiFont);

  skyColor = color(153, 213, 247);
  roadColor = color(63, 66, 73);

  calculateLayout();

  entityX = initialEntityX;
  updateEntityHeight();

  initializeObservers();
  rebuildDomainPoints();

  previousEntityY = entityY;
}

void calculateLayout() {
  roadY = height * 0.62;
  roadHeight = height - roadY;
  initialEntityX = width * 0.20;
}

float buttonTop() {
  return height - BUTTON_ROWS * 36 - 8;
}

float controlsTop() {
  return buttonTop() - 4;
}

float buttonHeight() {
  return 32;
}

float buttonGap() {
  return 4;
}

float buttonMargin() {
  return 6;
}

float buttonWidth() {
  return (width - 2 * buttonMargin()
    - buttonGap() * (BUTTON_COLS - 1)) / BUTTON_COLS;
}

float sliderY() {
  return buttonTop() - 22;
}

float sliderWidth() {
  return min(260, width * 0.30);
}

float sliderX() {
  return (width - sliderWidth()) * 0.5;
}

float observerAxisY() {
  return min(roadY + roadHeight * 0.70,
    controlsTop() - 12);
}

float getEntityScale() {
  return max(0.55, min(width / 1000.0, height / 500.0))
    * objectScale;
}

float getEntityBaseY() {
  if (currentEntity == 6 || currentEntity == 7) {
    return roadY + roadHeight * 0.35 - roadHeight * 0.45;
  }
  return roadY + roadHeight * 0.35 - 35 * getEntityScale();
}

void updateEntityHeight() {
  float baseY = getEntityBaseY();
  if (straightLineMode) {
    entityY = baseY;
  } else {
    entityY = baseY - sin(animationTime * 1.4)
      * 18 * getEntityScale();
  }
}

// ============================================================
// OBSERVERS
// ============================================================

void initializeObservers() {
  observerCount = 1;
  selectedObserver = 0;

  for (int i = 0; i < MAX_OBSERVERS; i++) {
    observerX[i] = round(width * (0.12 + 0.07 * i)
      / GRID_SPACING) * GRID_SPACING;

    observerY[i] = round(observerAxisY() / GRID_SPACING)
      * GRID_SPACING;

    observerVX[i] = 0;
    observerVY[i] = 0;

    observerFollows[i] = false;
    observerVisible[i] = true;
    randomPath[i] = false;

    observerNames[i] = "OBSERVER " + (i + 1);

    pathType[i] = 0;
    pathCenterX[i] = observerX[i];
    pathCenterY[i] = observerY[i];
    pathAmplitudeX[i] = 0;
    pathAmplitudeY[i] = 0;
    pathOmegaX[i] = 1;
    pathOmegaY[i] = 1;
    pathPhaseX[i] = 0;
    pathPhaseY[i] = 0;
  }

  observerX[0] = round(entityX / GRID_SPACING) * GRID_SPACING;
  observerY[0] = round(observerAxisY() / GRID_SPACING)
    * GRID_SPACING;
}

void addObserver() {
  if (observerCount >= MAX_OBSERVERS) return;

  int i = observerCount;

  observerX[i] = constrain(
    round((entityX + 80 * (i + 1)) / GRID_SPACING)
      * GRID_SPACING, 0, width);

  observerY[i] = constrain(
    round(observerAxisY() / GRID_SPACING) * GRID_SPACING,
    35, controlsTop());

  observerVX[i] = 0;
  observerVY[i] = 0;

  observerFollows[i] = false;
  observerVisible[i] = true;
  randomPath[i] = false;

  observerNames[i] = "OBSERVER " + (i + 1);

  observerCount++;
  selectedObserver = i;
  placingOrigin = false;
}

void selectNextObserver() {
  selectedObserver = (selectedObserver + 1) % observerCount;
  placingOrigin = false;
}

void selectPreviousObserver() {
  selectedObserver = (selectedObserver - 1 + observerCount)
    % observerCount;
  placingOrigin = false;
}

void deleteSelectedObserver() {
  if (selectedObserver == 0 || observerCount <= 1) return;

  for (int i = selectedObserver; i < observerCount - 1; i++) {
    observerX[i] = observerX[i + 1];
    observerY[i] = observerY[i + 1];
    observerVX[i] = observerVX[i + 1];
    observerVY[i] = observerVY[i + 1];

    observerFollows[i] = observerFollows[i + 1];
    observerVisible[i] = observerVisible[i + 1];
    randomPath[i] = randomPath[i + 1];

    observerNames[i] = observerNames[i + 1];

    pathType[i] = pathType[i + 1];
    pathCenterX[i] = pathCenterX[i + 1];
    pathCenterY[i] = pathCenterY[i + 1];
    pathAmplitudeX[i] = pathAmplitudeX[i + 1];
    pathAmplitudeY[i] = pathAmplitudeY[i + 1];
    pathOmegaX[i] = pathOmegaX[i + 1];
    pathOmegaY[i] = pathOmegaY[i + 1];
    pathPhaseX[i] = pathPhaseX[i + 1];
    pathPhaseY[i] = pathPhaseY[i + 1];
  }

  observerCount--;
  selectedObserver = min(selectedObserver, observerCount - 1);
  placingOrigin = false;
}

// ============================================================
// RANDOM PARAMETRIC AXIS MOTION
// ============================================================

void assignRandomPath(int i) {
  if (i < 0 || i >= observerCount) return;

  // Random path and entity-following mode are mutually exclusive.
  observerFollows[i] = false;

  // Randomize the path type and phase.
  pathType[i] = int(random(4));

  pathPhaseX[i] = random(TWO_PI);
  pathPhaseY[i] = random(TWO_PI);

  pathOmegaX[i] = random(0.45, 1.15);
  pathOmegaY[i] = random(0.40, 1.05);

  // Keep the origin inside the visible animation area.
  float minX = min(70, width * 0.10);
  float maxX = max(minX + 1, width - minX);

  float minY = 45;
  float maxY = max(minY + 1, controlsTop() - 20);

  observerX[i] = constrain(observerX[i], minX, maxX);
  observerY[i] = constrain(observerY[i], minY, maxY);

  // Choose a new path centre near the current origin.
  pathCenterX[i] = random(minX, maxX);
  pathCenterY[i] = random(minY, maxY);

  // Amplitudes are limited by available screen space.
  pathAmplitudeX[i] = min(
    random(width * 0.08, width * 0.22),
    min(pathCenterX[i] - minX, maxX - pathCenterX[i]));

  pathAmplitudeY[i] = min(
    random(height * 0.04, height * 0.12),
    min(pathCenterY[i] - minY, maxY - pathCenterY[i]));

  pathAmplitudeX[i] = max(0, pathAmplitudeX[i]);
  pathAmplitudeY[i] = max(0, pathAmplitudeY[i]);

  randomPath[i] = true;
  placingOrigin = false;
}

void updateRandomAxis(int i, float dt) {
  if (!randomPath[i] || i >= observerCount) return;

  float t = animationTime;

  float x = pathCenterX[i];
  float y = pathCenterY[i];

  float ax = pathAmplitudeX[i];
  float ay = pathAmplitudeY[i];

  float wx = pathOmegaX[i];
  float wy = pathOmegaY[i];

  float px = pathPhaseX[i];
  float py = pathPhaseY[i];

  // Four bounded parametric path families.
  if (pathType[i] == 0) {
    // Ellipse:
    // x = cx + Ax*cos(wx*t + px)
    // y = cy + Ay*sin(wy*t + py)
    x += ax * cos(wx * t + px);
    y += ay * sin(wy * t + py);
  } else if (pathType[i] == 1) {
    // Lissajous:
    // x = cx + Ax*sin(wx*t + px)
    // y = cy + Ay*sin(wy*t + py)
    x += ax * sin(wx * t + px);
    y += ay * sin(wy * t + py);
  } else if (pathType[i] == 2) {
    // Figure-eight:
    // x = cx + Ax*sin(wx*t + px)
    // y = cy + Ay*sin(2*wy*t + py)
    x += ax * sin(wx * t + px);
    y += ay * sin(2 * wy * t + py);
  } else {
    // Phase-shifted looping path.
    // x = cx + Ax*cos(wx*t + px)
    // y = cy + Ay*cos(2*wy*t + py)
    x += ax * cos(wx * t + px);
    y += ay * cos(2 * wy * t + py);
  }

  float minX = min(70, width * 0.10);
  float maxX = max(minX + 1, width - minX);
  float minY = 45;
  float maxY = max(minY + 1, controlsTop() - 20);

  float oldX = observerX[i];
  float oldY = observerY[i];

  observerX[i] = constrain(x, minX, maxX);
  observerY[i] = constrain(y, minY, maxY);

  // Approximate observer velocity in metres per second.
  if (dt > 0.0001) {
    observerVX[i] = (observerX[i] - oldX)
      / PIXELS_PER_METRE / dt;

    // Convert screen-down positive to mathematical +Y upward.
    observerVY[i] = -(observerY[i] - oldY)
      / PIXELS_PER_METRE / dt;
  }
}

// ============================================================
// MAIN LOOP
// ============================================================

void draw() {
  calculateLayout();

  updateSimulation();
  ensureDomainPoints();

  drawBackground();
  drawRoad();
  drawWorldGrid();
  drawEntity();

  drawAllPositionVectors();
  drawAllPointVelocityVectors();
  drawAllPointVelocityAxes();
  drawAllResultantVelocityVectors();

  drawSelectedPointVectors();
  drawRelativeVelocityVectors();
  drawObservers();

  drawHUD();
  drawScaleSlider();
  drawControls();
  drawPlacementMessage();
}

// ============================================================
// SIMULATION
// ============================================================

void updateSimulation() {
  // Fixed upper time-step bound prevents extreme jumps after stalls.
  float dt = min(0.05, 1.0 / max(frameRate, 1));

  float oldY = entityY;

  if (!paused) {
    animationTime += dt;
    elapsedTime += dt;

    float targetSpeed = throttle * maxSpeeds[currentEntity];

    speedKmh = lerp(speedKmh, targetSpeed,
      min(1.0, 0.8 * dt));

    float speedMS = speedKmh / 3.6;
    float displacement = speedMS * dt;

    worldDistance += displacement;
    objectTravelX += displacement * PIXELS_PER_METRE;

    float wrapWidth = max(1, width * 0.70);

    if (objectTravelX >= wrapWidth) {
      objectTravelX %= wrapWidth;
    }

    entityX = initialEntityX + objectTravelX;

    updateEntityHeight();

    entityVX = speedMS;

    if (straightLineMode || dt <= 0) {
      entityVY = 0;
    } else {
      entityVY = -((entityY - oldY)
        / PIXELS_PER_METRE) / dt;
    }
  } else {
    entityVX = 0;
    entityVY = 0;
  }

  for (int i = 0; i < observerCount; i++) {
    if (observerFollows[i]) {
      observerX[i] = entityX;
      observerY[i] = observerAxisY();

      observerVX[i] = entityVX;
      observerVY[i] = entityVY;
    } else if (randomPath[i] && !paused) {
      updateRandomAxis(i, dt);
    } else if (paused) {
      observerVX[i] = 0;
      observerVY[i] = 0;
    }
  }
}

// ============================================================
// VECTOR MATH
// ============================================================

float relativeVX(int i) {
  return entityVX - observerVX[i];
}

float relativeVY(int i) {
  return entityVY - observerVY[i];
}

float velocityMagnitude(float vx, float vy) {
  return sqrt(vx * vx + vy * vy);
}

float velocityAngleDegrees(float vx, float vy) {
  if (abs(vx) < 0.0001 && abs(vy) < 0.0001) return 0;
  return normalizeAngle(degrees(atan2(vy, vx)));
}

float normalizeAngle(float a) {
  return (a % 360 + 360) % 360;
}

float velocityScaleFor(float vx, float vy) {
  float mag = velocityMagnitude(vx, vy);
  if (mag < 0.001) return 0;
  return min(4.0, 100.0 / mag);
}

float metresBetween(float x1, float y1, float x2, float y2) {
  return dist(x1, y1, x2, y2) / PIXELS_PER_METRE;
}

float positionAngleDegrees(float ox, float oy, float px, float py) {
  float dx = (px - ox) / PIXELS_PER_METRE;
  float dy = (oy - py) / PIXELS_PER_METRE;

  if (abs(dx) < 0.0001 && abs(dy) < 0.0001) return 0;

  return normalizeAngle(degrees(atan2(dy, dx)));
}

// ============================================================
// BACKGROUND
// ============================================================

void drawBackground() {
  background((currentEntity == 6 || currentEntity == 7)
    ? color(100, 180, 255) : skyColor);

  noStroke();

  fill(255, 226, 128);
  ellipse(width * 0.84, height * 0.14,
    height * 0.14, height * 0.14);

  fill(108, 174, 125);
  beginShape();
  vertex(0, height * 0.39);
  vertex(width * 0.25, height * 0.38);
  vertex(width * 0.55, height * 0.39);
  vertex(width, height * 0.39);
  vertex(width, height);
  vertex(0, height);
  endShape(CLOSE);
}

void drawRoad() {
  noStroke();
  fill(roadColor);
  rect(0, roadY, width, roadHeight);

  fill(250, 245, 205);

  float dashW = width * 0.045;
  float cycle = max(1, dashW * 1.75);

  for (float x = 0; x < width; x += cycle) {
    rect(x, roadY + roadHeight * 0.55,
      dashW, max(2, height * 0.008));
  }
}

void drawWorldGrid() {
  if (!showWorldGrid) return;

  stroke(20, 60, 100, 65);
  strokeWeight(1);

  for (float x = 0; x <= width; x += GRID_SPACING) {
    line(x, 0, x, controlsTop());
  }

  for (float y = 0; y <= controlsTop(); y += GRID_SPACING) {
    line(0, y, width, y);
  }

  if (showCoordinates) {
    noStroke();
    fill(20, 55, 100, 220);
    textSize(10);
    textAlign(LEFT, CENTER);

    for (float x = 0; x < width; x += GRID_SPACING) {
      text(nf(x / PIXELS_PER_METRE, 0, 1) + " m",
        x + 2, 12);
    }

    text("WORLD GRID", 8, 28);
  }
}

// ============================================================
// ENTITY GEOMETRY
// ============================================================

void drawEntity() {
  pushMatrix();
  translate(entityX, entityY);
  scale(getEntityScale());

  drawEntityShape();

  if (showCells) drawEntitySubdivision();

  noStroke();

  for (int i = 0; i < pointCount; i++) {
    if (i == selectedPoint) {
      fill(255, 25, 35);
      ellipse(pointLocalX[i], pointLocalY[i], 8, 8);
    } else {
      fill(255, 210, 0, 210);
      ellipse(pointLocalX[i], pointLocalY[i], 3, 3);
    }
  }

  popMatrix();
}

void drawEntityShape() {
  noStroke();

  switch (currentEntity) {
  case 0:
    fill(220, 180, 150);
    ellipse(0, -60, 30, 30);
    fill(40, 100, 180);
    rect(-15, -45, 30, 50, 5);
    fill(50);
    rect(-12, 5, 10, 40);
    rect(2, 5, 10, 40);
    break;

  case 1:
    fill(30);
    ellipse(-40, 0, 35, 35);
    ellipse(40, 0, 35, 35);
    fill(190, 40, 40);
    rect(-50, -35, 100, 25, 10);
    fill(200);
    rect(20, -65, 5, 40);
    break;

  case 2:
    noFill();
    stroke(240);
    strokeWeight(4);
    ellipse(-40, 0, 40, 40);
    ellipse(40, 0, 40, 40);
    line(-40, 0, 0, -30);
    line(0, -30, 40, 0);
    line(40, 0, 20, -45);
    line(20, -45, -20, -45);
    line(-20, -45, -40, 0);
    break;

  case 3:
    fill(100, 70, 40);
    ellipse(-30, 0, 60, 60);
    rect(-60, -30, 80, 20);
    rect(20, -40, 40, 50, 10);
    break;

  case 4:
    fill(50);
    ellipse(-80, 10, 30, 30);
    ellipse(-30, 10, 30, 30);
    ellipse(70, 10, 30, 30);
    fill(150, 50, 50);
    rect(-100, -70, 140, 70);
    fill(40, 80, 150);
    rect(40, -50, 50, 50, 10);
    break;

  case 5:
    fill(30);
    ellipse(-50, 15, 25, 25);
    ellipse(50, 15, 25, 25);
    fill(50, 150, 200);
    rect(-70, -20, 140, 30, 10);
    rect(-40, -45, 80, 30, 15);
    break;

  case 6:
    fill(220);
    ellipse(0, 0, 160, 40);
    fill(180);
    triangle(-20, -20, 20, -20, -40, -70);
    fill(150);
    triangle(20, 10, -20, 10, 0, 60);
    break;

  case 7:
    fill(80);
    ellipse(0, 0, 60, 25);
    fill(100);
    triangle(-10, 0, 10, 0, 0, -40);
    fill(200, 150, 50);
    triangle(30, -5, 30, 5, 45, 0);
    break;

  case 8:
    fill(150, 200, 100);
    rect(-20, 10, 50, 10, 5);
    fill(200, 150, 100);
    ellipse(-10, -5, 40, 40);
    break;

  case 9:
    fill(50, 120, 60);
    ellipse(-25, 15, 15, 15);
    ellipse(25, 15, 15, 15);
    ellipse(40, 5, 20, 15);
    fill(100, 150, 80);
    arc(0, 15, 70, 50, PI, TWO_PI);
    break;

  case 10:
    fill(220, 170, 50);
    rect(-40, -20, 80, 25, 10);
    rect(-35, 0, 10, 30);
    rect(25, 0, 10, 30);
    ellipse(50, -25, 25, 25);
    break;

  case 11:
    fill(120);
    rect(-50, -60, 100, 80, 20);
    rect(-45, 20, 20, 30);
    rect(25, 20, 20, 30);
    ellipse(60, -40, 50, 50);
    rect(75, -30, 15, 60, 5);
    break;
  }
}

// ============================================================
// DOMAIN POINTS — CACHED
// ============================================================

boolean inRect(float x, float y,
  float x1, float y1, float x2, float y2) {
  return x >= x1 && x <= x2 && y >= y1 && y <= y2;
}

boolean inEllipse(float x, float y,
  float cx, float cy, float rx, float ry) {
  float dx = (x - cx) / rx;
  float dy = (y - cy) / ry;
  return dx * dx + dy * dy <= 1.0;
}

boolean pointInsideEntity(float x, float y) {
  switch (currentEntity) {
  case 0:
    return inEllipse(x, y, 0, -60, 15, 15)
      || inRect(x, y, -15, -45, 15, 5)
      || inRect(x, y, -12, 5, -2, 45)
      || inRect(x, y, 2, 5, 12, 45);

  case 1:
    return inEllipse(x, y, -40, 0, 17.5, 17.5)
      || inEllipse(x, y, 40, 0, 17.5, 17.5)
      || inRect(x, y, -50, -35, 50, -10)
      || inRect(x, y, 20, -65, 25, -25);

  case 2:
    return inEllipse(x, y, -40, 0, 20, 20)
      || inEllipse(x, y, 40, 0, 20, 20)
      || inRect(x, y, -25, -48, 25, -25)
      || inRect(x, y, -42, -3, 42, 3);

  case 3:
    return inEllipse(x, y, -30, 0, 30, 30)
      || inRect(x, y, -60, -30, 20, -10)
      || inRect(x, y, 20, -40, 60, 10);

  case 4:
    return inRect(x, y, -100, -70, 40, 0)
      || inRect(x, y, 40, -50, 90, 0)
      || inEllipse(x, y, -80, 10, 15, 15)
      || inEllipse(x, y, -30, 10, 15, 15)
      || inEllipse(x, y, 70, 10, 15, 15);

  case 5:
    return inRect(x, y, -70, -20, 70, 10)
      || inRect(x, y, -40, -45, 40, -15)
      || inEllipse(x, y, -50, 15, 12.5, 12.5)
      || inEllipse(x, y, 50, 15, 12.5, 12.5);

  case 6:
    return inEllipse(x, y, 0, 0, 80, 20)
      || inRect(x, y, -40, -70, 20, -20)
      || inRect(x, y, -20, 10, 20, 60);

  case 7:
    return inEllipse(x, y, 0, 0, 30, 12.5)
      || inRect(x, y, -10, -40, 10, 0)
      || inRect(x, y, 28, -5, 45, 5);

  case 8:
    return inRect(x, y, -20, 10, 30, 20)
      || inEllipse(x, y, -10, -5, 20, 20);

  case 9:
    return inEllipse(x, y, 0, 15, 35, 25)
      || inEllipse(x, y, -25, 15, 7.5, 7.5)
      || inEllipse(x, y, 25, 15, 7.5, 7.5)
      || inEllipse(x, y, 40, 5, 10, 7.5);

  case 10:
    return inRect(x, y, -40, -20, 40, 5)
      || inRect(x, y, -35, 0, -25, 30)
      || inRect(x, y, 25, 0, 35, 30)
      || inEllipse(x, y, 50, -25, 12.5, 12.5);

  case 11:
    return inRect(x, y, -50, -60, 50, 20)
      || inRect(x, y, -45, 20, -25, 50)
      || inRect(x, y, 25, 20, 45, 50)
      || inEllipse(x, y, 60, -40, 25, 25)
      || inRect(x, y, 75, -30, 90, 30);
  }
  return false;
}

void ensureDomainPoints() {
  if (pointsDirty
    || cachedEntity != currentEntity
    || abs(cachedCellSize - cellSize) > 0.001
    || abs(cachedScale - getEntityScale()) > 0.001) {
    rebuildDomainPoints();
  }
}

void rebuildDomainPoints() {
  pointCount = 0;

  float step = max(MIN_CELL_SIZE, cellSize);

  for (float x = -110; x <= 110 && pointCount < MAX_POINTS;
    x += step) {
    for (float y = -85; y <= 65 && pointCount < MAX_POINTS;
      y += step) {
      if (pointInsideEntity(x, y)) {
        pointLocalX[pointCount] = x;
        pointLocalY[pointCount] = y;
        pointCount++;
      }
    }
  }

  selectedPoint = pointCount > 0
    ? constrain(selectedPoint, 0, pointCount - 1) : 0;

  cachedEntity = currentEntity;
  cachedCellSize = cellSize;
  cachedScale = getEntityScale();
  pointsDirty = false;
}

void drawEntitySubdivision() {
  float step = max(MIN_CELL_SIZE, cellSize);

  stroke(255, 170, 0, 210);
  strokeWeight(0.7);
  noFill();

  for (float x = -110; x + step <= 110; x += step) {
    for (float y = -85; y + step <= 65; y += step) {
      if (pointInsideEntity(x, y)
        && pointInsideEntity(x + step, y)
        && pointInsideEntity(x, y + step)
        && pointInsideEntity(x + step, y + step)) {
        rect(x, y, step, step);
      }
    }
  }
}

float pointScreenX(int i) {
  return entityX + pointLocalX[i] * getEntityScale();
}

float pointScreenY(int i) {
  return entityY + pointLocalY[i] * getEntityScale();
}

// ============================================================
// ARROWS AND INFORMATION LABELS
// ============================================================

void drawArrow(float x1, float y1, float x2, float y2,
  int arrowColor, float sw) {
  stroke(arrowColor);
  strokeWeight(sw);
  line(x1, y1, x2, y2);

  float dx = x2 - x1;
  float dy = y2 - y1;

  if (dx * dx + dy * dy < 4) return;

  float a = atan2(dy, dx);
  float head = 7;

  line(x2, y2,
    x2 - head * cos(a - PI / 6),
    y2 - head * sin(a - PI / 6));

  line(x2, y2,
    x2 - head * cos(a + PI / 6),
    y2 - head * sin(a + PI / 6));
}

void drawInfoTag(float x, float y,
  String line1, String line2, int ink) {
  float bx = constrain(x, 3, max(3, width - 155));
  float by = constrain(y, 38, max(38, controlsTop() - 43));

  noStroke();
  fill(255, 250);
  rect(bx, by, 150, 38, 4);

  fill(ink);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(line1, bx + 5, by + 12);
  text(line2, bx + 5, by + 27);
}

// ============================================================
// POSITION VECTORS
// ============================================================

void drawAllPositionVectors() {
  if (!showAllPositionVectors || pointCount <= 0) return;

  float ox = observerX[selectedObserver];
  float oy = observerY[selectedObserver];

  for (int i = 0; i < pointCount; i++) {
    float px = pointScreenX(i);
    float py = pointScreenY(i);

    float mag = metresBetween(ox, oy, px, py);
    float ang = positionAngleDegrees(ox, oy, px, py);

    drawArrow(ox, oy, px, py,
      color(0, 110, 255, i == selectedPoint ? 255 : 110),
      i == selectedPoint ? 3 : 0.9);

    if (i == selectedPoint) {
      drawInfoTag(px + 10, py - 38,
        "|r| = " + nf(mag, 0, 3) + " m",
        "theta = " + nf(ang, 0, 1) + " deg",
        color(0, 55, 190));
    }
  }
}

// ============================================================
// ALL-POINT VELOCITY COMPONENTS
// ============================================================

void drawAllPointVelocityVectors() {
  if (!showAllPointVelocities || !showVelocity) return;

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);
  float sc = velocityScaleFor(vx, vy);

  for (int i = 0; i < pointCount; i++) {
    if (i == selectedPoint) continue;

    float px = pointScreenX(i);
    float py = pointScreenY(i);

    drawArrow(px, py, px + vx * sc, py,
      color(255, 145, 0, 190), 1.1);

    drawArrow(px, py, px, py - vy * sc,
      color(170, 50, 220, 190), 1.1);
  }
}

void drawAllPointVelocityAxes() {
  if (!showAllPointVelocityAxes || !showVelocity) return;

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);
  float sc = velocityScaleFor(vx, vy);

  for (int i = 0; i < pointCount; i++) {
    float px = pointScreenX(i);
    float py = pointScreenY(i);

    drawArrow(px, py, px + vx * sc, py,
      color(255, 120, 0, 235),
      i == selectedPoint ? 2.4 : 1.0);

    drawArrow(px, py, px, py - vy * sc,
      color(170, 40, 240, 235),
      i == selectedPoint ? 2.4 : 1.0);
  }
}

void drawAllResultantVelocityVectors() {
  if (!showAllResultantVectors || !showVelocity) return;

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);
  float mag = velocityMagnitude(vx, vy);
  float ang = velocityAngleDegrees(vx, vy);
  float sc = velocityScaleFor(vx, vy);

  for (int i = 0; i < pointCount; i++) {
    float px = pointScreenX(i);
    float py = pointScreenY(i);

    drawArrow(px, py, px + vx * sc, py - vy * sc,
      color(10, 75, 75, i == selectedPoint ? 255 : 180),
      i == selectedPoint ? 3.2 : 1.3);

    if (i == selectedPoint) {
      drawInfoTag(px + 10, py + 48,
        "|V| = " + nf(mag, 0, 3) + " m/s",
        "theta = " + nf(ang, 0, 1) + " deg",
        color(10, 75, 75));
    }
  }
}

// ============================================================
// SELECTED POINT VECTORS
// ============================================================

void drawSelectedPointVectors() {
  if (pointCount <= 0) return;

  float px = pointScreenX(selectedPoint);
  float py = pointScreenY(selectedPoint);

  float ox = observerX[selectedObserver];
  float oy = observerY[selectedObserver];

  noStroke();
  fill(255, 20, 30);
  ellipse(px, py, 13, 13);

  if (showPosition && !showAllPositionVectors) {
    float rMag = metresBetween(ox, oy, px, py);
    float rAngle = positionAngleDegrees(ox, oy, px, py);

    drawArrow(ox, oy, px, py, color(0, 110, 255), 3);

    drawInfoTag((ox + px) * 0.5 + 6,
      (oy + py) * 0.5 - 38,
      "|r| = " + nf(rMag, 0, 3) + " m",
      "theta = " + nf(rAngle, 0, 1) + " deg",
      color(0, 55, 190));
  }

  if (showVelocity) {
    float vx = relativeVX(selectedObserver);
    float vy = relativeVY(selectedObserver);

    float mag = velocityMagnitude(vx, vy);
    float ang = velocityAngleDegrees(vx, vy);
    float sc = velocityScaleFor(vx, vy);

    drawArrow(px, py, px + vx * sc, py,
      color(255, 145, 0), 3);

    drawArrow(px, py, px, py - vy * sc,
      color(170, 50, 220), 3);

    drawArrow(px, py, px + vx * sc, py - vy * sc,
      color(10, 75, 75), 3.4);

    drawInfoTag(px + 10, py + 8,
      "|V| = " + nf(mag, 0, 3) + " m/s",
      "theta = " + nf(ang, 0, 1) + " deg",
      color(10, 75, 75));

    fill(20, 20, 30);
    textSize(11);
    textAlign(LEFT, CENTER);

    text("P" + selectedPoint
      + "  Vx=" + nf(vx, 0, 3)
      + "  Vy=" + nf(vy, 0, 3) + " m/s",
      12, min(height * 0.48, controlsTop() - 30));
  }
}

// ============================================================
// OBSERVER AXES AND RELATIVE VELOCITY
// ============================================================

void drawObservers() {
  for (int i = 0; i < observerCount; i++) {
    if (!observerVisible[i]) continue;

    float ox = observerX[i];
    float oy = observerY[i];
    int c = observerColors[i];

    stroke(c, 165);
    strokeWeight(i == selectedObserver ? 2.5 : 1.2);
    line(ox, 35, ox, controlsTop());
    line(0, oy, width, oy);

    float pulse = i == selectedObserver
      ? 16 + 5 * sin(frameCount * 0.18) : 11;

    noFill();
    stroke(c);
    strokeWeight(2.5);
    ellipse(ox, oy, pulse, pulse);

    noStroke();
    fill(c);
    ellipse(ox, oy, 6, 6);

    if (showLabels) {
      float lx = constrain(ox + 8, 2, max(2, width - 160));
      float ly = constrain(oy - 25, 38,
        max(38, controlsTop() - 22));

      fill(255, 255, 255, 235);
      rect(lx, ly, 155, 20, 4);

      fill(c);
      textSize(9);
      textAlign(LEFT, CENTER);

      String mode = observerFollows[i] ? "FOLLOW"
        : randomPath[i] ? "RANDOM" : "FIXED";

      text(observerNames[i] + " " + mode, lx + 4, ly + 10);
    }
  }
}

void drawRelativeVelocityVectors() {
  if (!showRelative) return;

  for (int i = 0; i < observerCount; i++) {
    if (!observerVisible[i]) continue;

    float vx = relativeVX(i);
    float vy = relativeVY(i);
    float mag = velocityMagnitude(vx, vy);
    float ang = velocityAngleDegrees(vx, vy);
    float sc = velocityScaleFor(vx, vy);

    float sx = observerX[i];
    float sy = observerY[i] - 35 - i * 8;

    drawArrow(sx, sy, sx + vx * sc, sy - vy * sc,
      observerColors[i], i == selectedObserver ? 2.5 : 1.2);

    if (i == selectedObserver && showCoordinates) {
      fill(observerColors[i]);
      textSize(10);
      textAlign(LEFT, CENTER);

      text("v(A/B)=(" + nf(vx, 0, 2)
        + "," + nf(vy, 0, 2) + ") m/s"
        + " |v|=" + nf(mag, 0, 2)
        + " theta=" + nf(ang, 0, 1) + " deg",
        constrain(sx + 12, 4, max(4, width - 300)),
        constrain(sy - 20, 42, max(42, controlsTop() - 20)));
    }
  }
}

// ============================================================
// TELEMETRY
// ============================================================

void drawHUD() {
  float px = 10;
  float py = 10;
  float panelW = min(390, width * 0.46);
  float panelH = 205;

  noStroke();
  fill(10, 22, 38, 225);
  rect(px, py, panelW, panelH, 9);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13);
  text("DYNAMIC VECTOR TELEMETRY", px + 10, py + 15);

  fill(190, 230, 255);
  textSize(10);

  text("Entity: " + entityNames[currentEntity], px + 10, py + 34);

  text("Motion: " + (straightLineMode
    ? "STRAIGHT LINE" : "FREE / VERTICAL"), px + 10, py + 50);

  text("Speed: " + nf(speedKmh, 0, 2) + " km/h",
    px + 10, py + 66);

  text("Absolute V: (" + nf(entityVX, 0, 3)
    + ", " + nf(entityVY, 0, 3) + ") m/s",
    px + 10, py + 82);

  text("Distance: " + nf(worldDistance, 0, 2)
    + " m | Time: " + nf(elapsedTime, 0, 2) + " s",
    px + 10, py + 98);

  text("Axes: " + observerCount + "/" + MAX_OBSERVERS
    + " | Point: " + selectedPoint
    + "/" + max(0, pointCount - 1),
    px + 10, py + 114);

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);

  text("Relative V: (" + nf(vx, 0, 3)
    + ", " + nf(vy, 0, 3) + ") m/s",
    px + 10, py + 130);

  text("|V| = " + nf(velocityMagnitude(vx, vy), 0, 3)
    + " m/s | theta = "
    + nf(velocityAngleDegrees(vx, vy), 0, 1) + " deg",
    px + 10, py + 146);

  text("X/Y AXES: " + (showAllPointVelocityAxes ? "ON" : "OFF"),
    px + 10, py + 162);

  text("RESULTANT ALL: " + (showAllResultantVectors ? "ON" : "OFF"),
    px + 10, py + 178);

  text("POSITION ALL: " + (showAllPositionVectors ? "ON" : "OFF"),
    px + 10, py + 194);

  if (randomPath[selectedObserver]) {
    fill(255, 235, 120);
    textAlign(LEFT, CENTER);
    text("RANDOM PATH ACTIVE — " + pathName(pathType[selectedObserver]),
      px + 10, py + panelH + 14);
  }
}

String pathName(int type) {
  if (type == 0) return "ELLIPSE";
  if (type == 1) return "LISSAJOUS";
  if (type == 2) return "FIGURE EIGHT";
  return "LOOP";
}

// ============================================================
// OBJECT-SCALE SLIDER
// ============================================================

void drawScaleSlider() {
  float sx = sliderX();
  float sy = sliderY();
  float sw = sliderWidth();

  stroke(150);
  strokeWeight(4);
  line(sx, sy, sx + sw, sy);

  float knobX = sx + norm(objectScale, 0.5, 3.0) * sw;

  noStroke();
  fill(draggingSlider ? color(255, 230, 80) : color(255, 200, 0));
  ellipse(knobX, sy, 15, 15);

  fill(20, 30, 40);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("OBJECT SIZE " + nf(objectScale, 0, 2),
    width * 0.5, sy - 12);
}

// ============================================================
// BUTTON LABELS
// ============================================================

String[] getButtonLabels() {
  return new String[] {
    "BRAKE",
    "THROTTLE",
    paused ? "RESUME" : "PAUSE",
    "NEXT OBJ",
    "ADD AXIS",
    "PREV AXIS",

    "NEXT AXIS",
    observerFollows[selectedObserver] ? "FIX AXIS" : "MOVE AXIS",
    observerVisible[selectedObserver] ? "AXIS ON" : "AXIS OFF",
    "PLACE ORIGIN",
    "DELETE AXIS",
    showCoordinates ? "COORDS ON" : "COORDS OFF",

    showRelative ? "REL VEL ON" : "REL VEL OFF",
    showVelocity ? "VEL ON" : "VEL OFF",
    showPosition ? "POS ON" : "POS OFF",
    showWorldGrid ? "WORLD ON" : "WORLD OFF",
    showCells ? "CELLS ON" : "CELLS OFF",
    showLabels ? "LABELS ON" : "LABELS OFF",

    "CELL -",
    "CELL +",
    snapToGrid ? "SNAP ON" : "SNAP OFF",
    "RESET",
    "PREV POINT",
    "NEXT POINT",

    showAllPointVelocities ? "ALL VEL ON" : "ALL VEL OFF",
    showAllPositionVectors ? "ALL POS ON" : "ALL POS OFF",
    showAllPointVelocityAxes ? "VEL AXES ON" : "VEL AXES OFF",
    showAllResultantVectors ? "RESULT ALL ON" : "RESULT ALL OFF",
    straightLineMode ? "STRAIGHT ON" : "STRAIGHT OFF",
    randomPath[selectedObserver] ? "RANDOM OFF" : "RANDOM PATH"
  };
}

int getButtonColor(int i) {
  switch (i) {
  case 0: return color(190, 50, 50);
  case 1: return color(40, 150, 80);
  case 2: return color(60, 90, 140);
  case 3: return color(230, 125, 0);
  case 4: return color(0, 135, 190);
  case 5:
  case 6: return color(90, 90, 130);
  case 7: return color(40, 125, 150);
  case 8: return color(30, 125, 100);
  case 9: return color(175, 70, 30);
  case 10: return color(155, 55, 55);
  case 11: return color(70, 100, 150);
  case 12: return color(145, 70, 160);
  case 13: return color(190, 110, 20);
  case 14: return color(0, 135, 180);
  case 15: return color(40, 100, 140);
  case 16: return color(140, 100, 30);
  case 17: return color(80, 90, 110);
  case 18:
  case 19: return color(70, 100, 130);
  case 20: return color(130, 80, 120);
  case 21: return color(90, 95, 105);
  case 22:
  case 23: return color(170, 55, 55);
  case 24: return showAllPointVelocities
      ? color(180, 50, 170) : color(100, 65, 135);
  case 25: return showAllPositionVectors
      ? color(0, 95, 255) : color(35, 65, 150);
  case 26: return showAllPointVelocityAxes
      ? color(10, 155, 95) : color(45, 95, 100);
  case 27: return showAllResultantVectors
      ? color(0, 150, 145) : color(40, 95, 100);
  case 28: return straightLineMode
      ? color(20, 170, 80) : color(170, 90, 25);
  case 29: return randomPath[selectedObserver]
      ? color(210, 55, 180) : color(115, 45, 130);
  }
  return color(65, 70, 80);
}

// ============================================================
// TOUCH CONTROLS
// ============================================================

void drawControls() {
  String[] labels = getButtonLabels();

  float bw = buttonWidth();
  float bh = buttonHeight();
  float gap = buttonGap();
  float margin = buttonMargin();

  noStroke();
  fill(18, 24, 34);
  rect(0, buttonTop() - 2, width, height - buttonTop() + 2);

  textSize(10);
  textAlign(CENTER, CENTER);

  for (int i = 0; i < BUTTON_COUNT; i++) {
    int row = i / BUTTON_COLS;
    int col = i % BUTTON_COLS;

    float bx = margin + col * (bw + gap);
    float by = buttonTop() + row * 36;

    fill(getButtonColor(i));
    rect(bx, by, bw, bh, 5);

    fill(255);
    text(labels[i], bx + bw * 0.5, by + bh * 0.5);
  }

  textAlign(LEFT, CENTER);
}

void drawPlacementMessage() {
  if (!placingOrigin) return;

  float boxW = min(width * 0.62, 460);
  float boxX = (width - boxW) * 0.5;

  noStroke();
  fill(20, 20, 30, 230);
  rect(boxX, 38, boxW, 30, 6);

  fill(255, 240, 120);
  textSize(12);
  textAlign(CENTER, CENTER);

  text(snapToGrid
    ? "TAP ANIMATION AREA: ORIGIN SNAPS TO GRID"
    : "TAP ANIMATION AREA TO PLACE ORIGIN",
    width * 0.5, 53);

  textAlign(LEFT, CENTER);
}

// ============================================================
// AXIS PLACEMENT AND TOUCH
// ============================================================

void setSelectedAxisPosition(float x, float y) {
  if (observerFollows[selectedObserver]
    || randomPath[selectedObserver]) return;

  if (snapToGrid) {
    x = round(x / GRID_SPACING) * GRID_SPACING;
    y = round(y / GRID_SPACING) * GRID_SPACING;
  }

  observerX[selectedObserver] = constrain(x, 0, width);
  observerY[selectedObserver] = constrain(y, 35, controlsTop());

  observerVX[selectedObserver] = 0;
  observerVY[selectedObserver] = 0;
  placingOrigin = false;
}

boolean nearSelectedOrigin(float x, float y) {
  return dist(x, y, observerX[selectedObserver],
    observerY[selectedObserver]) < 28;
}

void mousePressed() {
  float sx = sliderX();
  float sy = sliderY();
  float sw = sliderWidth();
  float knobX = sx + norm(objectScale, 0.5, 3.0) * sw;

  if (dist(mouseX, mouseY, knobX, sy) < 23
    || (mouseY >= sy - 12 && mouseY <= sy + 12
    && mouseX >= sx && mouseX <= sx + sw)) {
    draggingSlider = true;
    updateScaleFromTouch();
    return;
  }

  float bw = buttonWidth();
  float bh = buttonHeight();
  float gap = buttonGap();
  float margin = buttonMargin();

  int row = int((mouseY - buttonTop()) / 36);

  if (row >= 0 && row < BUTTON_ROWS) {
    int col = int((mouseX - margin) / (bw + gap));

    if (col >= 0 && col < BUTTON_COLS) {
      float bx = margin + col * (bw + gap);
      float by = buttonTop() + row * 36;

      if (mouseX >= bx && mouseX <= bx + bw
        && mouseY >= by && mouseY <= by + bh) {
        int idx = row * BUTTON_COLS + col;
        if (idx < BUTTON_COUNT) handleButton(idx);
        return;
      }
    }
  }

  if (!observerFollows[selectedObserver]
    && !randomPath[selectedObserver]
    && observerVisible[selectedObserver]
    && mouseY > 35 && mouseY < sliderY() - 10
    && nearSelectedOrigin(mouseX, mouseY)) {
    draggingAxis = true;
    placingOrigin = false;
    return;
  }

  if (mouseY > 35 && mouseY < sliderY() - 10
    && !observerFollows[selectedObserver]
    && !randomPath[selectedObserver]) {
    if (placingOrigin || !nearSelectedOrigin(mouseX, mouseY)) {
      setSelectedAxisPosition(mouseX, mouseY);
    }
  }
}

void mouseDragged() {
  if (draggingSlider) {
    updateScaleFromTouch();
    return;
  }

  if (draggingAxis
    && !observerFollows[selectedObserver]
    && !randomPath[selectedObserver]) {
    observerX[selectedObserver] = constrain(mouseX, 0, width);
    observerY[selectedObserver] = constrain(mouseY, 35, controlsTop());

    observerVX[selectedObserver] = 0;
    observerVY[selectedObserver] = 0;
  }
}

void mouseReleased() {
  draggingSlider = false;

  if (draggingAxis && snapToGrid) {
    observerX[selectedObserver] =
      round(observerX[selectedObserver] / GRID_SPACING)
      * GRID_SPACING;

    observerY[selectedObserver] =
      round(observerY[selectedObserver] / GRID_SPACING)
      * GRID_SPACING;
  }

  observerX[selectedObserver] =
    constrain(observerX[selectedObserver], 0, width);

  observerY[selectedObserver] =
    constrain(observerY[selectedObserver], 35, controlsTop());

  draggingAxis = false;
}

void updateScaleFromTouch() {
  float t = constrain(
    (mouseX - sliderX()) / max(1, sliderWidth()), 0, 1);

  objectScale = lerp(0.5, 3.0, t);
  pointsDirty = true;
}

// ============================================================
// BUTTON ACTIONS
// ============================================================

void handleButton(int idx) {
  switch (idx) {
  case 0:
    throttle = max(0, throttle - 0.35);
    break;

  case 1:
    throttle = min(1, throttle + 0.20);
    break;

  case 2:
    paused = !paused;
    if (paused) {
      entityVX = 0;
      entityVY = 0;
      for (int i = 0; i < observerCount; i++) {
        observerVX[i] = 0;
        observerVY[i] = 0;
      }
    }
    break;

  case 3:
    currentEntity = (currentEntity + 1) % ENTITY_COUNT;
    pointsDirty = true;
    resetSimulation();
    break;

  case 4:
    addObserver();
    break;

  case 5:
    selectPreviousObserver();
    break;

  case 6:
    selectNextObserver();
    break;

  case 7:
    observerFollows[selectedObserver] =
      !observerFollows[selectedObserver];

    placingOrigin = false;

    if (observerFollows[selectedObserver]) {
      randomPath[selectedObserver] = false;
      observerX[selectedObserver] = entityX;
      observerY[selectedObserver] = observerAxisY();
      observerVX[selectedObserver] = entityVX;
      observerVY[selectedObserver] = entityVY;
    } else {
      observerVX[selectedObserver] = 0;
      observerVY[selectedObserver] = 0;
    }
    break;

  case 8:
    observerVisible[selectedObserver] =
      !observerVisible[selectedObserver];
    break;

  case 9:
    if (!observerFollows[selectedObserver]
      && !randomPath[selectedObserver]) {
      placingOrigin = true;
    }
    break;

  case 10:
    deleteSelectedObserver();
    break;

  case 11:
    showCoordinates = !showCoordinates;
    break;

  case 12:
    showRelative = !showRelative;
    break;

  case 13:
    showVelocity = !showVelocity;
    break;

  case 14:
    showPosition = !showPosition;
    break;

  case 15:
    showWorldGrid = !showWorldGrid;
    break;

  case 16:
    showCells = !showCells;
    break;

  case 17:
    showLabels = !showLabels;
    break;

  case 18:
    cellSize = max(MIN_CELL_SIZE, cellSize - 2);
    pointsDirty = true;
    selectedPoint = 0;
    break;

  case 19:
    cellSize = min(MAX_CELL_SIZE, cellSize + 2);
    pointsDirty = true;
    selectedPoint = 0;
    break;

  case 20:
    snapToGrid = !snapToGrid;
    break;

  case 21:
    resetSimulation();
    break;

  case 22:
    if (pointCount > 0) {
      selectedPoint = (selectedPoint - 1 + pointCount) % pointCount;
    }
    break;

  case 23:
    if (pointCount > 0) {
      selectedPoint = (selectedPoint + 1) % pointCount;
    }
    break;

  case 24:
    showAllPointVelocities = !showAllPointVelocities;
    break;

  case 25:
    showAllPositionVectors = !showAllPositionVectors;
    break;

  case 26:
    showAllPointVelocityAxes = !showAllPointVelocityAxes;
    break;

  case 27:
    showAllResultantVectors = !showAllResultantVectors;
    break;

  case 28:
    straightLineMode = !straightLineMode;
    animationTime = 0;
    updateEntityHeight();

    if (straightLineMode) entityVY = 0;

    for (int i = 0; i < observerCount; i++) {
      if (observerFollows[i]) {
        observerX[i] = entityX;
        observerY[i] = observerAxisY();
        observerVX[i] = entityVX;
        observerVY[i] = entityVY;
      }
    }
    break;

  case 29:
    // Independent RANDOM PATH button.
    // Works on any selected observer, including a newly added axis.
    if (randomPath[selectedObserver]) {
      randomPath[selectedObserver] = false;
      observerVX[selectedObserver] = 0;
      observerVY[selectedObserver] = 0;
    } else {
      assignRandomPath(selectedObserver);
    }
    break;
  }
}

// ============================================================
// RESET
// ============================================================

void resetSimulation() {
  speedKmh = 0;
  worldDistance = 0;
  elapsedTime = 0;
  objectTravelX = 0;
  animationTime = 0;

  throttle = 0.35;
  paused = false;

  initialEntityX = width * 0.20;
  entityX = initialEntityX;

  updateEntityHeight();

  entityVX = 0;
  entityVY = 0;

  selectedPoint = 0;
  placingOrigin = false;
  draggingAxis = false;

  for (int i = 0; i < observerCount; i++) {
    if (observerFollows[i]) {
      observerX[i] = entityX;
      observerY[i] = observerAxisY();
    }

    // Random paths remain assigned, but reset their phases in time.
    observerVX[i] = 0;
    observerVY[i] = 0;
  }

  pointsDirty = true;
  rebuildDomainPoints();
}
