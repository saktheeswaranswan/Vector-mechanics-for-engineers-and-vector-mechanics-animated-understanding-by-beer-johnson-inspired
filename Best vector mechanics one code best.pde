/*
 MECHANICS VECTORS FOR ENGINEERS
 DYNAMIC POSITION, COMPONENT AND RESULTANT VECTORS
 Processing Android Mode / Java Mode

 FEATURES
 1. Twelve animated entities
 2. Eight coordinate observers
 3. Fixed and moving observers
 4. Grid-snapped origin placement
 5. Grid points inside entity shapes
 6. Selected red grid point
 7. Dynamic position magnitude and direction
 8. Dynamic X and Y velocity components
 9. Dynamic resultant velocity magnitude and direction
10. All-point velocity toggle
11. All-point position-vector toggle
12. All-point velocity-axis toggle
13. All-point resultant-vector toggle
14. Previous/next point selection
15. Cell-size and object-scale controls
16. Touch-friendly five-row button panel
17. Telemetry, pause, throttle and reset
18. Dynamic horizontal and vertical entity motion
19. NEW: Straight-line / free-motion toggle
20. Straight-line mode removes vertical oscillation
21. All vector calculations update dynamically

 Paste into one Processing .pde file.
*/

final int MAX_OBSERVERS = 8;
final int ENTITY_COUNT = 12;
final int BUTTONS_PER_ROW = 7;
final int BUTTON_COUNT = 29;
final int BUTTON_ROWS = 5;
final int MAX_POINTS = 5000;

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
float entityVX = 0;
float entityVY = 0;

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

String[] observerNames = new String[MAX_OBSERVERS];

int[] observerColors = {
  0xFF00A6FF, 0xFFFF4040,
  0xFF20C878, 0xFFFFA020,
  0xFFB070FF, 0xFFFF55AA,
  0xFF20D0D0, 0xFFFFFF60
};

// ============================================================
// INITIALIZATION
// ============================================================

void settings() {
  fullScreen();
}

void setup() {
  orientation(LANDSCAPE);
  frameRate(60);
  smooth(4);

  uiFont = createFont("sans-serif", 16, true);
  textFont(uiFont);

  skyColor = color(153, 213, 247);
  roadColor = color(63, 66, 73);

  calculateLayout();

  entityX = initialEntityX;
  updateEntityHeight();

  initializeObservers();
  buildDomainPoints();
}

void calculateLayout() {
  roadY = height * 0.62;
  roadHeight = height - roadY;
  initialEntityX = width * 0.20;
}

float buttonTop() {
  return height - BUTTON_ROWS * 35 - 8;
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
  return 8;
}

float buttonWidth() {
  return (width - 2 * buttonMargin()
    - buttonGap() * (BUTTONS_PER_ROW - 1))
    / BUTTONS_PER_ROW;
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
  return min(
    roadY + roadHeight * 0.70,
    controlsTop() - 12
  );
}

float getEntityScale() {
  return max(
    0.55,
    min(width / 1000.0, height / 500.0)
  ) * objectScale;
}

// ============================================================
// ENTITY VERTICAL POSITION
// ============================================================

float getEntityBaseY() {
  if (currentEntity == 6 || currentEntity == 7) {
    return roadY + roadHeight * 0.35
      - roadHeight * 0.45;
  }

  return roadY + roadHeight * 0.35
    - 35 * getEntityScale();
}

void updateEntityHeight() {
  float baseY = getEntityBaseY();

  if (straightLineMode) {
    // Straight-line motion: no vertical displacement.
    entityY = baseY;
  } else {
    // Normal mode: horizontal travel plus vertical oscillation.
    entityY = baseY
      + sin(animationTime * 1.4)
      * 18 * getEntityScale();
  }
}

// ============================================================
// OBSERVER INITIALIZATION
// ============================================================

void initializeObservers() {
  observerCount = 1;
  selectedObserver = 0;

  for (int i = 0; i < MAX_OBSERVERS; i++) {
    observerX[i] = round(
      width * (0.12 + 0.07 * i) / GRID_SPACING
    ) * GRID_SPACING;

    observerY[i] = round(
      observerAxisY() / GRID_SPACING
    ) * GRID_SPACING;

    observerVX[i] = 0;
    observerVY[i] = 0;

    observerFollows[i] = false;
    observerVisible[i] = true;

    observerNames[i] = "OBSERVER " + (i + 1);
  }

  observerFollows[0] = false;

  observerX[0] = round(entityX / GRID_SPACING)
    * GRID_SPACING;

  observerY[0] = round(observerAxisY() / GRID_SPACING)
    * GRID_SPACING;
}

// ============================================================
// MAIN DRAW LOOP
// ============================================================

void draw() {
  calculateLayout();

  updateSimulation();
  buildDomainPoints();

  drawBackground();
  drawRoad();
  drawWorldGrid();

  drawEntity();
  drawObservers();

  drawAllPositionVectors();
  drawAllPointVelocityVectors();
  drawAllPointVelocityAxes();
  drawAllResultantVelocityVectors();

  drawSelectedPointVectors();
  drawRelativeVelocityVectors();

  drawHUD();
  drawScaleSlider();
  drawControls();
  drawPlacementMessage();
}

// ============================================================
// SIMULATION AND VELOCITY CALCULATION
// ============================================================

void updateSimulation() {
  float dt = min(0.05, 1.0 / max(frameRate, 1));

  float oldY = entityY;

  if (!paused) {
    animationTime += dt;
    elapsedTime += dt;

    float targetSpeed = throttle * maxSpeeds[currentEntity];

    speedKmh = lerp(
      speedKmh,
      targetSpeed,
      min(1.0, 0.8 * dt)
    );

    float speedMS = speedKmh / 3.6;
    float displacement = speedMS * dt;

    worldDistance += displacement;
    objectTravelX += displacement * PIXELS_PER_METRE;

    float wrapWidth = width * 0.70;

    if (objectTravelX >= wrapWidth) {
      objectTravelX -= wrapWidth;
      initialEntityX = width * 0.15;
    }

    entityX = initialEntityX + objectTravelX;

    updateEntityHeight();

    // Horizontal velocity in metres per second.
    entityVX = speedMS;

    // Screen Y increases downward, so invert the difference.
    if (straightLineMode) {
      entityVY = 0;
    } else if (dt > 0) {
      entityVY = -(
        (entityY - oldY) / PIXELS_PER_METRE
      ) / dt;
    }
  } else {
    entityVX = 0;
    entityVY = 0;
  }

  // Update observers.
  for (int i = 0; i < observerCount; i++) {
    if (observerFollows[i]) {
      observerX[i] = entityX;
      observerY[i] = observerAxisY();

      observerVX[i] = entityVX;
      observerVY[i] = entityVY;
    } else {
      observerVX[i] = 0;
      observerVY[i] = 0;
    }
  }
}

// ============================================================
// RELATIVE VELOCITY AND VECTOR MATH
// ============================================================

float relativeVX(int observer) {
  return entityVX - observerVX[observer];
}

float relativeVY(int observer) {
  return entityVY - observerVY[observer];
}

float velocityMagnitude(float vx, float vy) {
  return sqrt(vx * vx + vy * vy);
}

float velocityAngleDegrees(float vx, float vy) {
  if (abs(vx) < 0.0001 && abs(vy) < 0.0001) {
    return 0;
  }

  return normalizeAngle(degrees(atan2(vy, vx)));
}

float normalizeAngle(float angle) {
  while (angle < 0) angle += 360;
  while (angle >= 360) angle -= 360;
  return angle;
}

float velocityScaleFor(float vx, float vy) {
  float mag = velocityMagnitude(vx, vy);

  if (mag < 0.001) return 0;

  // This controls visual arrow length, not the actual velocity.
  return min(4.0, 100.0 / mag);
}

// ============================================================
// BACKGROUND
// ============================================================

void drawBackground() {
  background(
    (currentEntity == 6 || currentEntity == 7)
    ? color(100, 180, 255)
    : skyColor
  );

  noStroke();

  fill(255, 226, 128);
  ellipse(
    width * 0.84,
    height * 0.14,
    height * 0.14,
    height * 0.14
  );

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

// ============================================================
// ROAD
// ============================================================

void drawRoad() {
  noStroke();
  fill(roadColor);
  rect(0, roadY, width, roadHeight);

  fill(250, 245, 205);

  float dashW = width * 0.045;
  float cycle = dashW * 1.75;

  for (float x = 0; x < width; x += cycle) {
    rect(
      x,
      roadY + roadHeight * 0.55,
      dashW,
      max(2, height * 0.008)
    );
  }
}

// ============================================================
// WORLD GRID
// ============================================================

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
      text(
        nf(x / PIXELS_PER_METRE, 0, 1) + " m",
        x + 2, 12
      );
    }

    text("WORLD GRID", 8, 28);
  }
}

// ============================================================
// ENTITY DRAWING
// ============================================================

void drawEntity() {
  pushMatrix();
  translate(entityX, entityY);
  scale(getEntityScale());

  drawEntityShape();

  if (showCells) {
    drawEntitySubdivision();
  }

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

// ============================================================
// TWELVE ENTITY SHAPES
// ============================================================

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
// DOMAIN GEOMETRY HELPERS
// ============================================================

boolean inRect(float x, float y,
  float x1, float y1, float x2, float y2) {
  return x >= x1 && x <= x2
    && y >= y1 && y <= y2;
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

// ============================================================
// BUILD GRID POINTS
// ============================================================

void buildDomainPoints() {
  pointCount = 0;

  float step = max(MIN_CELL_SIZE, cellSize);

  for (float x = -110; x <= 110; x += step) {
    for (float y = -85; y <= 65; y += step) {
      if (pointInsideEntity(x, y)
        && pointCount < MAX_POINTS) {
        pointLocalX[pointCount] = x;
        pointLocalY[pointCount] = y;
        pointCount++;
      }
    }
  }

  if (pointCount <= 0) {
    selectedPoint = 0;
  } else {
    selectedPoint = constrain(
      selectedPoint, 0, pointCount - 1
    );
  }
}

void drawEntitySubdivision() {
  float step = max(MIN_CELL_SIZE, cellSize);

  stroke(255, 170, 0, 210);
  strokeWeight(0.7);
  noFill();

  for (float x = -110; x + step <= 110; x += step) {
    for (float y = -85; y + step <= 65; y += step) {
      boolean contained =
        pointInsideEntity(x, y)
        && pointInsideEntity(x + step, y)
        && pointInsideEntity(x, y + step)
        && pointInsideEntity(x + step, y + step);

      if (contained) rect(x, y, step, step);
    }
  }
}

// ============================================================
// POINT COORDINATES AND POSITION MATH
// ============================================================

float pointScreenX(int i) {
  return entityX + pointLocalX[i] * getEntityScale();
}

float pointScreenY(int i) {
  return entityY + pointLocalY[i] * getEntityScale();
}

float metresBetween(float x1, float y1,
  float x2, float y2) {
  return dist(x1, y1, x2, y2) / PIXELS_PER_METRE;
}

float positionAngleDegrees(float ox, float oy,
  float px, float py) {
  float dx = (px - ox) / PIXELS_PER_METRE;
  float dy = (oy - py) / PIXELS_PER_METRE;

  if (abs(dx) < 0.0001 && abs(dy) < 0.0001) {
    return 0;
  }

  return normalizeAngle(degrees(atan2(dy, dx)));
}

// ============================================================
// ARROW AND LABEL HELPERS
// ============================================================

void drawArrow(float x1, float y1,
  float x2, float y2, int arrowColor, float sw) {

  stroke(arrowColor);
  strokeWeight(sw);
  line(x1, y1, x2, y2);

  float dx = x2 - x1;
  float dy = y2 - y1;

  if (dx * dx + dy * dy < 4) return;

  float a = atan2(dy, dx);
  float head = 7;

  line(
    x2, y2,
    x2 - head * cos(a - PI / 6),
    y2 - head * sin(a - PI / 6)
  );

  line(
    x2, y2,
    x2 - head * cos(a + PI / 6),
    y2 - head * sin(a + PI / 6)
  );
}

void drawInfoTag(float x, float y,
  String line1, String line2, int ink) {

  float bx = constrain(x, 3, width - 155);
  float by = constrain(y, 38, controlsTop() - 43);

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
// ALL POSITION VECTORS
// ============================================================

void drawAllPositionVectors() {
  if (!showAllPositionVectors || pointCount <= 0) return;

  float ox = observerX[selectedObserver];
  float oy = observerY[selectedObserver];

  for (int i = 0; i < pointCount; i++) {
    float px = pointScreenX(i);
    float py = pointScreenY(i);

    float mag = metresBetween(ox, oy, px, py);
    float angleDeg = positionAngleDegrees(ox, oy, px, py);

    drawArrow(
      ox, oy, px, py,
      color(0, 110, 255, i == selectedPoint ? 255 : 110),
      i == selectedPoint ? 3 : 0.9
    );

    if (i == selectedPoint) {
      drawInfoTag(
        px + 10, py - 38,
        "|r| = " + nf(mag, 0, 3) + " m",
        "θr = " + nf(angleDeg, 0, 1) + "°",
        color(0, 55, 190)
      );
    } else if (i % 5 == 0) {
      fill(0, 35, 130, 230);
      noStroke();
      textSize(8);
      textAlign(LEFT, CENTER);

      text(
        nf(mag, 0, 1) + " m / "
          + nf(angleDeg, 0, 0) + "°",
        constrain((ox + px) * 0.5, 2, width - 65),
        constrain((oy + py) * 0.5, 35, controlsTop() - 8)
      );
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

    drawArrow(
      px, py, px + vx * sc, py,
      color(255, 145, 0, 190), 1.1
    );

    drawArrow(
      px, py, px, py - vy * sc,
      color(170, 50, 220, 190), 1.1
    );
  }
}

// ============================================================
// ALL-POINT VELOCITY AXES
// ============================================================

void drawAllPointVelocityAxes() {
  if (!showAllPointVelocityAxes || !showVelocity) return;

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);
  float sc = velocityScaleFor(vx, vy);

  for (int i = 0; i < pointCount; i++) {
    float px = pointScreenX(i);
    float py = pointScreenY(i);

    drawArrow(
      px, py, px + vx * sc, py,
      color(255, 120, 0, 235),
      i == selectedPoint ? 2.4 : 1.0
    );

    drawArrow(
      px, py, px, py - vy * sc,
      color(170, 40, 240, 235),
      i == selectedPoint ? 2.4 : 1.0
    );

    if (i == selectedPoint) {
      drawInfoTag(
        px + 8, py + 8,
        "Vx = " + nf(vx, 0, 3) + " m/s",
        "Vy = " + nf(vy, 0, 3) + " m/s",
        color(125, 20, 200)
      );
    }
  }
}

// ============================================================
// ALL-POINT RESULTANT VELOCITY
// ============================================================

void drawAllResultantVelocityVectors() {
  if (!showAllResultantVectors || !showVelocity) return;

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);

  float mag = velocityMagnitude(vx, vy);
  float angleDeg = velocityAngleDegrees(vx, vy);
  float sc = velocityScaleFor(vx, vy);

  for (int i = 0; i < pointCount; i++) {
    float px = pointScreenX(i);
    float py = pointScreenY(i);

    drawArrow(
      px, py,
      px + vx * sc, py - vy * sc,
      color(10, 75, 75, i == selectedPoint ? 255 : 180),
      i == selectedPoint ? 3.2 : 1.3
    );

    if (i == selectedPoint) {
      drawInfoTag(
        px + 10, py + 48,
        "|V| = " + nf(mag, 0, 3) + " m/s",
        "θ = " + nf(angleDeg, 0, 1) + "°",
        color(10, 75, 75)
      );
    } else if (i % 5 == 0) {
      fill(10, 60, 60, 235);
      noStroke();
      textSize(8);
      textAlign(LEFT, CENTER);

      text(
        nf(mag, 0, 2) + " m/s "
          + nf(angleDeg, 0, 0) + "°",
        constrain(px + 3, 2, width - 65),
        constrain(py - 12, 35, controlsTop() - 8)
      );
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

    drawArrow(
      ox, oy, px, py,
      color(0, 110, 255), 3
    );

    drawInfoTag(
      (ox + px) * 0.5 + 6,
      (oy + py) * 0.5 - 38,
      "|r| = " + nf(rMag, 0, 3) + " m",
      "θr = " + nf(rAngle, 0, 1) + "°",
      color(0, 55, 190)
    );
  }

  if (showVelocity) {
    float vx = relativeVX(selectedObserver);
    float vy = relativeVY(selectedObserver);

    float mag = velocityMagnitude(vx, vy);
    float angleDeg = velocityAngleDegrees(vx, vy);
    float sc = velocityScaleFor(vx, vy);

    // X component.
    drawArrow(
      px, py, px + vx * sc, py,
      color(255, 145, 0), 3
    );

    // Y component.
    drawArrow(
      px, py, px, py - vy * sc,
      color(170, 50, 220), 3
    );

    // Resultant velocity.
    drawArrow(
      px, py, px + vx * sc, py - vy * sc,
      color(10, 75, 75), 3.4
    );

    drawInfoTag(
      px + 10, py + 8,
      "|V| = " + nf(mag, 0, 3) + " m/s",
      "θ = " + nf(angleDeg, 0, 1) + "° from +X",
      color(10, 75, 75)
    );

    fill(20, 20, 30);
    textSize(11);
    textAlign(LEFT, CENTER);

    text(
      "P" + selectedPoint
        + "  Vx=" + nf(vx, 0, 3)
        + "  Vy=" + nf(vy, 0, 3) + " m/s",
      12, min(height * 0.48, controlsTop() - 30)
    );
  }
}

// ============================================================
// OBSERVER AXES
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
      ? 16 + 5 * sin(frameCount * 0.18)
      : 11;

    noFill();
    stroke(c);
    strokeWeight(2.5);
    ellipse(ox, oy, pulse, pulse);

    noStroke();
    fill(c);
    ellipse(ox, oy, 6, 6);

    if (showLabels) {
      float lx = constrain(ox + 8, 2, width - 140);
      float ly = constrain(oy - 25, 38, controlsTop() - 22);

      fill(255, 255, 255, 235);
      rect(lx, ly, 136, 20, 4);

      fill(c);
      textSize(10);
      textAlign(LEFT, CENTER);

      text(
        observerNames[i]
          + (observerFollows[i] ? " MOVING" : " FIXED"),
        lx + 4, ly + 10
      );
    }
  }
}

// ============================================================
// RELATIVE VELOCITY AT OBSERVERS
// ============================================================

void drawRelativeVelocityVectors() {
  if (!showRelative) return;

  for (int i = 0; i < observerCount; i++) {
    if (!observerVisible[i]) continue;

    float vx = entityVX - observerVX[i];
    float vy = entityVY - observerVY[i];

    float mag = velocityMagnitude(vx, vy);
    float angleDeg = velocityAngleDegrees(vx, vy);
    float sc = velocityScaleFor(vx, vy);

    float sx = observerX[i];
    float sy = observerY[i] - 35 - i * 8;

    drawArrow(
      sx, sy, sx + vx * sc, sy - vy * sc,
      observerColors[i],
      i == selectedObserver ? 2.5 : 1.2
    );

    if (i == selectedObserver && showCoordinates) {
      fill(observerColors[i]);
      textSize(10);
      textAlign(LEFT, CENTER);

      text(
        "v(A/B)=(" + nf(vx, 0, 2)
          + "," + nf(vy, 0, 2) + ") m/s"
          + " |v|=" + nf(mag, 0, 2)
          + " θ=" + nf(angleDeg, 0, 1) + "°",
        constrain(sx + 12, 4, width - 300),
        constrain(sy - 20, 42, controlsTop() - 20)
      );
    }
  }
}

// ============================================================
// TELEMETRY HUD
// ============================================================

void drawHUD() {
  float px = 10;
  float py = 10;
  float panelW = min(375, width * 0.44);
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

  text("Entity: " + entityNames[currentEntity],
    px + 10, py + 34);

  text("Motion: "
    + (straightLineMode ? "STRAIGHT LINE" : "FREE / VERTICAL"),
    px + 10, py + 50);

  text("Speed: " + nf(speedKmh, 0, 2) + " km/h",
    px + 10, py + 66);

  text("Absolute V: (" + nf(entityVX, 0, 3)
    + ", " + nf(entityVY, 0, 3) + ") m/s",
    px + 10, py + 82);

  text("Distance: " + nf(worldDistance, 0, 2)
    + " m | Time: " + nf(elapsedTime, 0, 2) + " s",
    px + 10, py + 98);

  text("Observers: " + observerCount + "/" + MAX_OBSERVERS
    + " | Point: " + selectedPoint
    + "/" + max(0, pointCount - 1),
    px + 10, py + 114);

  float vx = relativeVX(selectedObserver);
  float vy = relativeVY(selectedObserver);
  float mag = velocityMagnitude(vx, vy);
  float angleDeg = velocityAngleDegrees(vx, vy);

  text("Relative V: (" + nf(vx, 0, 3)
    + ", " + nf(vy, 0, 3) + ") m/s",
    px + 10, py + 130);

  text("|V| = " + nf(mag, 0, 3)
    + " m/s | θ = " + nf(angleDeg, 0, 1) + "°",
    px + 10, py + 146);

  fill(showAllPointVelocityAxes
    ? color(100, 255, 160)
    : color(210, 220, 235));

  text("X/Y AXES: "
    + (showAllPointVelocityAxes ? "ON" : "OFF"),
    px + 10, py + 162);

  fill(showAllResultantVectors
    ? color(100, 255, 160)
    : color(210, 220, 235));

  text("RESULTANT ALL: "
    + (showAllResultantVectors ? "ON" : "OFF"),
    px + 10, py + 178);

  fill(showAllPositionVectors
    ? color(100, 255, 160)
    : color(210, 220, 235));

  text("POSITION ALL: "
    + (showAllPositionVectors ? "ON" : "OFF"),
    px + 10, py + 194);
}

// ============================================================
// OBJECT SCALE SLIDER
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
  fill(draggingSlider
    ? color(255, 230, 80)
    : color(255, 200, 0));

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

    observerFollows[selectedObserver]
      ? "FIX AXIS" : "MOVE AXIS",

    observerVisible[selectedObserver]
      ? "AXIS ON" : "AXIS OFF",

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

    showAllPointVelocities
      ? "ALL VEL ON" : "ALL VEL OFF",

    showAllPositionVectors
      ? "ALL POS ON" : "ALL POS OFF",

    showAllPointVelocityAxes
      ? "VEL AXES ON" : "VEL AXES OFF",

    showAllResultantVectors
      ? "RESULT ALL ON" : "RESULT ALL OFF",

    straightLineMode
      ? "STRAIGHT ON" : "STRAIGHT OFF"
  };
}

// ============================================================
// BUTTON COLORS
// ============================================================

int getButtonColor(int i) {
  switch (i) {
  case 0: return color(190, 50, 50);
  case 1: return color(40, 150, 80);
  case 2: return color(60, 90, 140);
  case 3: return color(230, 125, 0);
  case 4: return color(0, 135, 190);
  case 5: return color(90, 90, 130);
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
  case 18: return color(70, 100, 130);
  case 19: return color(70, 100, 130);
  case 20: return color(130, 80, 120);
  case 21: return color(90, 95, 105);
  case 22: return color(170, 55, 55);
  case 23: return color(200, 45, 45);

  case 24:
    return showAllPointVelocities
      ? color(180, 50, 170)
      : color(100, 65, 135);

  case 25:
    return showAllPositionVectors
      ? color(0, 95, 255)
      : color(35, 65, 150);

  case 26:
    return showAllPointVelocityAxes
      ? color(10, 155, 95)
      : color(45, 95, 100);

  case 27:
    return showAllResultantVectors
      ? color(0, 150, 145)
      : color(40, 95, 100);

  case 28:
    return straightLineMode
      ? color(20, 170, 80)
      : color(170, 90, 25);
  }

  return color(65, 70, 80);
}

// ============================================================
// DRAW TOUCH CONTROLS
// ============================================================

void drawControls() {
  String[] labels = getButtonLabels();

  float bw = buttonWidth();
  float bh = buttonHeight();
  float gap = buttonGap();
  float margin = buttonMargin();

  noStroke();
  fill(18, 24, 34);
  rect(0, buttonTop() - 2,
    width, height - buttonTop() + 2);

  textSize(10);
  textAlign(CENTER, CENTER);

  for (int i = 0; i < BUTTON_COUNT; i++) {
    int row = i / BUTTONS_PER_ROW;
    int col = i % BUTTONS_PER_ROW;

    float bx;
    float by = buttonTop() + row * 35;

    // Center the single new button in the final row.
    if (row == 4) {
      bx = (width - bw) * 0.5;
    } else {
      bx = margin + col * (bw + gap);
    }

    noStroke();
    fill(getButtonColor(i));
    rect(bx, by, bw, bh, 5);

    fill(255);
    text(labels[i], bx + bw * 0.5, by + bh * 0.5);
  }

  textAlign(LEFT, CENTER);
}

// ============================================================
// PLACE ORIGIN MESSAGE
// ============================================================

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

  text(
    snapToGrid
      ? "TAP ANIMATION AREA: ORIGIN SNAPS TO GRID"
      : "TAP ANIMATION AREA TO PLACE ORIGIN",
    width * 0.5, 53
  );

  textAlign(LEFT, CENTER);
}

// ============================================================
// OBSERVER MANAGEMENT
// ============================================================

void addObserver() {
  if (observerCount >= MAX_OBSERVERS) return;

  int i = observerCount;

  observerX[i] = round(
    width * (0.12 + 0.07 * i) / GRID_SPACING
  ) * GRID_SPACING;

  observerY[i] = round(
    observerAxisY() / GRID_SPACING
  ) * GRID_SPACING;

  observerVX[i] = 0;
  observerVY[i] = 0;

  observerFollows[i] = false;
  observerVisible[i] = true;

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
  selectedObserver--;

  if (selectedObserver < 0) {
    selectedObserver = observerCount - 1;
  }

  placingOrigin = false;
}

void deleteSelectedObserver() {
  if (selectedObserver == 0 || observerCount <= 1) return;

  for (int i = selectedObserver;
    i < observerCount - 1; i++) {

    observerX[i] = observerX[i + 1];
    observerY[i] = observerY[i + 1];

    observerVX[i] = observerVX[i + 1];
    observerVY[i] = observerVY[i + 1];

    observerFollows[i] = observerFollows[i + 1];
    observerVisible[i] = observerVisible[i + 1];

    observerNames[i] = observerNames[i + 1];
    observerColors[i] = observerColors[i + 1];
  }

  observerCount--;

  if (selectedObserver >= observerCount) {
    selectedObserver = observerCount - 1;
  }

  placingOrigin = false;
}

// ============================================================
// TOUCH INPUT
// ============================================================

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

  int row = int((mouseY - buttonTop()) / 35);

  if (row >= 0 && row < BUTTON_ROWS) {
    int col = int((mouseX - margin) / (bw + gap));

    if (row == 4) {
      // The final row contains one centered button.
      float bx = (width - bw) * 0.5;
      float by = buttonTop() + row * 35;

      if (mouseX >= bx && mouseX <= bx + bw
        && mouseY >= by && mouseY <= by + bh) {
        handleButton(28);
        return;
      }
    } else if (col >= 0 && col < BUTTONS_PER_ROW) {
      float bx = margin + col * (bw + gap);
      float by = buttonTop() + row * 35;

      if (mouseX >= bx && mouseX <= bx + bw
        && mouseY >= by && mouseY <= by + bh) {

        int idx = row * BUTTONS_PER_ROW + col;

        if (idx < 28) {
          handleButton(idx);
          return;
        }
      }
    }
  }

  if (mouseY > 35 && mouseY < sliderY() - 10
    && !observerFollows[selectedObserver]) {

    float x = constrain(mouseX, 0, width);
    float y = constrain(mouseY, 35, controlsTop());

    if (snapToGrid) {
      x = round(x / GRID_SPACING) * GRID_SPACING;
      y = round(y / GRID_SPACING) * GRID_SPACING;

      x = constrain(x, 0, width);
      y = constrain(y, 35, controlsTop());
    }

    observerX[selectedObserver] = x;
    observerY[selectedObserver] = y;
    placingOrigin = false;
  }
}

void mouseDragged() {
  if (draggingSlider) {
    updateScaleFromTouch();
  }
}

void mouseReleased() {
  draggingSlider = false;
}

void updateScaleFromTouch() {
  float t = constrain(
    (mouseX - sliderX()) / sliderWidth(),
    0, 1
  );

  objectScale = lerp(0.5, 3.0, t);
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
    }
    break;

  case 3:
    currentEntity = (currentEntity + 1) % ENTITY_COUNT;
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
    if (!observerFollows[selectedObserver]) {
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
    selectedPoint = 0;
    break;

  case 19:
    cellSize = min(MAX_CELL_SIZE, cellSize + 2);
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
      selectedPoint--;

      if (selectedPoint < 0) {
        selectedPoint = pointCount - 1;
      }
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
    // NEW: toggle straight-line motion for the selected object.
    straightLineMode = !straightLineMode;

    // Restart the vertical phase to prevent a sudden jump
    // when switching between the two movement modes.
    animationTime = 0;

    updateEntityHeight();

    if (straightLineMode) {
      entityVY = 0;
    }

    // Refresh observers immediately after changing the mode.
    for (int i = 0; i < observerCount; i++) {
      if (observerFollows[i]) {
        observerX[i] = entityX;
        observerY[i] = observerAxisY();
        observerVX[i] = entityVX;
        observerVY[i] = entityVY;
      }
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

  for (int i = 0; i < observerCount; i++) {
    if (observerFollows[i]) {
      observerX[i] = entityX;
      observerY[i] = observerAxisY();
    }

    observerVX[i] = 0;
    observerVY[i] = 0;
  }

  buildDomainPoints();
}
