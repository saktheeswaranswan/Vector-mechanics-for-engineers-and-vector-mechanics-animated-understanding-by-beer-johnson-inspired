Mechanics vectors for engineers 



/*
 MULTI-ENTITY VELOCITY & POSITION VECTOR VISUALIZER
 Processing Android Mode / Java Mode
 No external libraries required.

 FEATURES
 1. Twelve selectable moving entities.
 2. STATIC global coordinate grid.
 3. Object moves independently across the screen.
 4. Fixed grid distance labels in metres.
 5. Cumulative travelled distance and elapsed time.
 6. Shape-aware square subdivision.
 7. Grid ON/OFF independent of velocity vectors.
 8. Velocity vectors from valid square centres.
 9. Position vectors from a fixed screen reference.
10. Optional X,Y labels at sample points.
11. Adjustable grid-cell size and object scale.
12. Throttle, brake, pause, reset and next entity.
13. Headlight/reference vector.
14. Touch-friendly controls.

 COORDINATE CONVENTION
 - Grid spacing is fixed in screen pixels.
 - Grid lines and labels never scroll.
 - The object moves horizontally across the grid.
 - worldDistance is cumulative distance travelled in metres.
 - Grid X coordinates are measured from the fixed grid origin.
 - This is a visualization, not a calibrated physical CFD model.

 CELL CONTAINMENT:
 Nine-point testing approximates fully contained cells.
 For exact curved-boundary clipping, use geometric intersection tests.
*/

float speedKmh = 0;
float targetSpeed = 0;
float throttle = 0.35;
float worldDistance = 0;
float elapsedTime = 0;

// Cumulative movement converted to screen pixels.
float objectTravelX = 0;

boolean paused = false;
boolean showVectors = true;
boolean showPositionVectors = false;
boolean showHeadlightVector = false;

boolean showGrid = true;
boolean showWorldGrid = true;
boolean showXYLabels = false;

float gridCellSize = 12;
float minCellSize = 6;
float maxCellSize = 30;

float roadY;
float roadHeight;
float entityX;
float entityY;
float scooterScale = 2.0;

boolean draggingSlider = false;

int backgroundSky;
int roadColor;
PFont uiFont;

int currentScreen = 0;

String[] entityNames = {
  "MAN", "SCOOTER", "BICYCLE", "BULLOCK CART",
  "LORRY", "CAR", "AEROPLANE", "BIRD",
  "SNAIL", "TORTOISE", "LEOPARD", "ELEPHANT"
};

float[] maxSpeeds = {
  15, 90, 30, 15, 120, 180,
  900, 60, 1, 3, 110, 40
};

float hx, hy;

final float PIXELS_PER_METRE = 16.0;
final float WORLD_GRID_SPACING = 50.0;

// Initial object screen position.
float initialEntityX;

// Object moves across a fixed screen grid and wraps around
// when it leaves the right edge. Cumulative distance never resets
// unless RESET or NEXT ENTITY is selected.

void settings() {
  fullScreen();
}

void setup() {
  orientation(LANDSCAPE);
  frameRate(60);
  smooth(4);

  uiFont = createFont("sans-serif", 16, true);
  textFont(uiFont);

  backgroundSky = color(153, 213, 247);
  roadColor = color(63, 66, 73);

  initialEntityX = width * 0.20;
}

void draw() {
  updateSimulation();

  drawBackground();

  // Road and distance marks are stationary.
  drawRoad();
  drawDistanceMarkers();

  // Global grid is stationary and independent of the object.
  if (showWorldGrid) {
    drawWorldCoordinateGrid();
  }

  drawEntityBase();
  drawHUD();
  drawScaleSlider();
  drawControls();
}

// ==================================================
// SIMULATION
// ==================================================

void updateSimulation() {
  float dt = min(0.05, 1.0 / max(frameRate, 1));

  if (paused) return;

  targetSpeed = throttle * maxSpeeds[currentScreen];

  speedKmh = lerp(
    speedKmh,
    targetSpeed,
    min(1.0, 0.8 * dt)
  );

  float distanceThisFrame = (speedKmh / 3.6) * dt;

  worldDistance += distanceThisFrame;
  elapsedTime += dt;

  // Convert travelled distance to screen movement.
  objectTravelX += distanceThisFrame * PIXELS_PER_METRE;

  // Wrap the object for continuous animation.
  // The world grid remains fixed; cumulative distance remains
  // monotonic and is not reset by this visual wrap.
  float wrapWidth = width * 0.72;

  if (objectTravelX >= wrapWidth) {
    objectTravelX -= wrapWidth;
  }
}

// ==================================================
// ENVIRONMENT
// ==================================================

void drawBackground() {
  if (currentScreen == 6 || currentScreen == 7) {
    background(color(100, 180, 255));
  } else {
    background(backgroundSky);
  }

  noStroke();

  fill(255, 226, 128);
  ellipse(
    width * 0.83, height * 0.14,
    width * 0.09, width * 0.09
  );

  fill(108, 174, 125);

  beginShape();
  vertex(0, height * 0.40);
  vertex(width * 0.25, height * 0.39);
  vertex(width * 0.55, height * 0.40);
  vertex(width, height * 0.40);
  vertex(width, height);
  vertex(0, height);
  endShape(CLOSE);
}

// Stationary road. No distance-dependent offset.
void drawRoad() {
  roadY = height * 0.65;
  roadHeight = height * 0.35;

  noStroke();
  fill(roadColor);
  rect(0, roadY, width, roadHeight);

  fill(250, 245, 205);

  float dashW = width * 0.045;
  float cycle = dashW * 1.75;

  for (float x = 0; x < width; x += cycle) {
    rect(
      x,
      roadY + roadHeight * 0.56,
      dashW,
      height * 0.008
    );
  }
}

// Stationary road distance ticks.
void drawDistanceMarkers() {
  float spacing = width * 0.10;

  for (float x = 0; x < width; x += spacing) {
    stroke(220);
    strokeWeight(2);

    line(
      x, roadY + roadHeight * 0.31,
      x, roadY + roadHeight * 0.335
    );
  }

  noStroke();
}

// ==================================================
// STATIC WORLD GRID AND FIXED DISTANCE LABELS
// ==================================================

void drawWorldCoordinateGrid() {
  float spacing = WORLD_GRID_SPACING;

  // The fixed coordinate origin never follows the object.
  float ox = width * 0.10;
  float oy = roadY + roadHeight * 0.85;

  stroke(20, 60, 100, 85);
  strokeWeight(1);

  // Vertical lines to the right of the origin.
  for (float x = ox; x < width; x += spacing) {
    line(x, 0, x, height);
  }

  // Vertical lines to the left of the origin.
  for (float x = ox - spacing; x >= 0; x -= spacing) {
    line(x, 0, x, height);
  }

  // Horizontal lines.
  for (float y = oy; y < height; y += spacing) {
    line(0, y, width, y);
  }

  for (float y = oy - spacing; y >= 0; y -= spacing) {
    line(0, y, width, y);
  }

  // Fixed X and Y axes.
  stroke(20, 65, 120, 210);
  strokeWeight(2);

  line(ox, 0, ox, height);
  line(0, oy, width, oy);

  // Distance labels remain attached to fixed grid lines.
  textSize(10);
  textAlign(LEFT, CENTER);
  noStroke();

  for (float x = ox; x < width; x += spacing) {
    float xMetres = (x - ox) / PIXELS_PER_METRE;

    fill(20, 55, 100, 230);

    text(
      nf(xMetres, 0, 2) + " m",
      x + 3,
      constrain(oy + 14, 12, height - 12)
    );
  }

  for (float x = ox - spacing; x >= 0; x -= spacing) {
    float xMetres = (x - ox) / PIXELS_PER_METRE;

    fill(20, 55, 100, 230);

    text(
      nf(xMetres, 0, 2) + " m",
      x + 3,
      constrain(oy + 14, 12, height - 12)
    );
  }

  fill(20, 55, 100, 240);
  textSize(11);

  text("STATIC WORLD GRID", 8, 18);
  text("X = 0 m", ox + 4, max(30, oy - 6));
  text("Y = 0", 5, oy - 6);

  textAlign(LEFT, CENTER);
}

// ==================================================
// OBJECT TRANSFORM AND RENDERING
// ==================================================

void drawEntityBase() {
  float s = getEntityScale();

  // Horizontal position changes; grid coordinates do not.
  entityX = initialEntityX + objectTravelX;

  float altitude =
    (currentScreen == 6 || currentScreen == 7)
    ? roadHeight * 1.2
    : 22 * s;

  entityY = roadY + roadHeight * 0.65 - altitude;

  pushMatrix();

  translate(entityX, entityY);
  scale(s);

  drawActiveEntityShape();

  if (showGrid || showVectors ||
      showPositionVectors || showXYLabels) {
    drawSubdividedVelocityVectors();
  }

  if (showHeadlightVector) {
    drawRedHeadVector();
  }

  popMatrix();
}

float getEntityScale() {
  return max(
    0.55,
    min(width / 1000.0, height / 500.0)
  ) * scooterScale;
}

// ==================================================
// ENTITY SHAPES
// ==================================================

void drawActiveEntityShape() {
  noStroke();

  switch (currentScreen) {

  case 0: // MAN
    fill(220, 180, 150);
    ellipse(0, -60, 30, 30);

    fill(40, 100, 180);
    rect(-15, -45, 30, 50, 5);

    fill(50);
    rect(-12, 5, 10, 40);
    rect(2, 5, 10, 40);

    hx = 15;
    hy = -65;
    break;

  case 1: // SCOOTER
    fill(30);
    ellipse(-40, 0, 35, 35);
    ellipse(40, 0, 35, 35);

    fill(190, 40, 40);
    rect(-50, -35, 100, 25, 10);

    fill(200);
    rect(20, -65, 5, 40);

    fill(255, 240, 150);
    ellipse(35, -30, 10, 15);

    hx = 40;
    hy = -30;
    break;

  case 2: // BICYCLE
    stroke(200);
    strokeWeight(4);
    noFill();

    ellipse(-40, 0, 40, 40);
    ellipse(40, 0, 40, 40);

    line(-40, 0, 0, -30);
    line(0, -30, 40, 0);
    line(40, 0, 20, -45);
    line(20, -45, -20, -45);
    line(-20, -45, -40, 0);

    noStroke();
    fill(220, 180, 150);
    ellipse(10, -80, 25, 25);

    fill(40, 150, 80);
    rect(-10, -65, 20, 40, 5);

    hx = 25;
    hy = -80;
    break;

  case 3: // BULLOCK CART
    fill(100, 70, 40);
    ellipse(-30, 0, 60, 60);
    rect(-60, -30, 80, 20);

    stroke(100, 70, 40);
    strokeWeight(5);
    line(20, -20, 70, -20);

    noStroke();
    fill(200);
    rect(50, -40, 40, 50, 10);
    ellipse(90, -30, 20, 20);

    hx = 100;
    hy = -30;
    break;

  case 4: // LORRY
    fill(50);
    ellipse(-80, 10, 30, 30);
    ellipse(-30, 10, 30, 30);
    ellipse(70, 10, 30, 30);

    fill(150, 50, 50);
    rect(-100, -70, 140, 70);

    fill(40, 80, 150);
    rect(40, -50, 50, 50, 10);

    fill(200, 230, 255);
    rect(65, -40, 25, 20);

    hx = 90;
    hy = -20;
    break;

  case 5: // CAR
    fill(30);
    ellipse(-50, 15, 25, 25);
    ellipse(50, 15, 25, 25);

    fill(50, 150, 200);
    rect(-70, -20, 140, 30, 10);
    rect(-40, -45, 80, 30, 20, 20, 0, 0);

    hx = 70;
    hy = -10;
    break;

  case 6: // AEROPLANE
    fill(220);
    ellipse(0, 0, 160, 40);

    fill(180);
    triangle(-20, -20, 20, -20, -40, -70);

    fill(150);
    triangle(20, 10, -20, 10, 0, 60);

    hx = 80;
    hy = 0;
    break;

  case 7: // BIRD
    fill(80);
    ellipse(0, 0, 60, 25);

    fill(100);
    triangle(-10, 0, 10, 0, 0, -40);

    fill(200, 150, 50);
    triangle(30, -5, 30, 5, 45, 0);

    hx = 45;
    hy = 0;
    break;

  case 8: // SNAIL
    fill(150, 200, 100);
    rect(-20, 10, 50, 10, 5);

    stroke(150, 200, 100);
    strokeWeight(2);
    line(30, 10, 40, -10);

    noStroke();
    fill(200, 150, 100);
    ellipse(-10, -5, 40, 40);

    hx = 40;
    hy = -10;
    break;

  case 9: // TORTOISE
    fill(50, 120, 60);
    ellipse(-25, 15, 15, 15);
    ellipse(25, 15, 15, 15);
    ellipse(40, 5, 20, 15);

    fill(100, 150, 80);
    arc(0, 15, 70, 50, PI, TWO_PI);

    hx = 50;
    hy = 5;
    break;

  case 10: // LEOPARD
    fill(220, 170, 50);
    rect(-40, -20, 80, 25, 10);

    rect(-35, 0, 10, 30);
    rect(25, 0, 10, 30);

    ellipse(50, -25, 25, 25);

    fill(30);
    ellipse(-10, -10, 5, 5);
    ellipse(10, -5, 5, 5);
    ellipse(-25, -5, 5, 5);

    hx = 60;
    hy = -25;
    break;

  case 11: // ELEPHANT
    fill(120);
    rect(-50, -60, 100, 80, 20);

    rect(-45, 20, 20, 30);
    rect(25, 20, 20, 30);

    ellipse(60, -40, 50, 50);
    rect(75, -30, 15, 60, 5);

    hx = 90;
    hy = -10;
    break;
  }
}

// ==================================================
// GEOMETRY HELPERS
// ==================================================

boolean inRect(float x, float y,
               float rx, float ry,
               float rw, float rh) {
  return x >= rx && x <= rx + rw &&
         y >= ry && y <= ry + rh;
}

boolean inEllipse(float x, float y,
                  float cx, float cy,
                  float w, float h) {
  if (w <= 0 || h <= 0) return false;

  float dx = (x - cx) / (w * 0.5);
  float dy = (y - cy) / (h * 0.5);

  return dx * dx + dy * dy <= 1.0;
}

boolean inTriangle(float px, float py,
                   float ax, float ay,
                   float bx, float by,
                   float cx, float cy) {
  float d1 = (px - bx) * (ay - by) -
             (ax - bx) * (py - by);

  float d2 = (px - cx) * (by - cy) -
             (bx - cx) * (py - cy);

  float d3 = (px - ax) * (cy - ay) -
             (cx - ax) * (py - ay);

  boolean neg = d1 < 0 || d2 < 0 || d3 < 0;
  boolean pos = d1 > 0 || d2 > 0 || d3 > 0;

  return !(neg && pos);
}

boolean nearSegment(float px, float py,
                    float ax, float ay,
                    float bx, float by,
                    float radius) {
  float dx = bx - ax;
  float dy = by - ay;
  float len2 = dx * dx + dy * dy;

  if (len2 == 0) {
    return dist(px, py, ax, ay) <= radius;
  }

  float t = ((px - ax) * dx +
             (py - ay) * dy) / len2;

  t = constrain(t, 0, 1);

  float qx = ax + t * dx;
  float qy = ay + t * dy;

  return dist(px, py, qx, qy) <= radius;
}

// ==================================================
// OBJECT SHAPE MASK
// ==================================================

boolean isInsideEntity(float x, float y) {
  switch (currentScreen) {

  case 0: // MAN
    return inEllipse(x, y, 0, -60, 30, 30) ||
           inRect(x, y, -15, -45, 30, 50) ||
           inRect(x, y, -12, 5, 10, 40) ||
           inRect(x, y, 2, 5, 10, 40);

  case 1: // SCOOTER
    return inEllipse(x, y, -40, 0, 35, 35) ||
           inEllipse(x, y, 40, 0, 35, 35) ||
           inRect(x, y, -50, -35, 100, 25) ||
           inRect(x, y, 20, -65, 5, 40) ||
           inEllipse(x, y, 35, -30, 10, 15);

  case 2: // BICYCLE
    return inEllipse(x, y, -40, 0, 40, 40) ||
           inEllipse(x, y, 40, 0, 40, 40) ||
           nearSegment(x, y, -40, 0, 0, -30, 2.5) ||
           nearSegment(x, y, 0, -30, 40, 0, 2.5) ||
           nearSegment(x, y, 40, 0, 20, -45, 2.5) ||
           nearSegment(x, y, 20, -45, -20, -45, 2.5) ||
           nearSegment(x, y, -20, -45, -40, 0, 2.5) ||
           inEllipse(x, y, 10, -80, 25, 25) ||
           inRect(x, y, -10, -65, 20, 40);

  case 3: // BULLOCK CART
    return inEllipse(x, y, -30, 0, 60, 60) ||
           inRect(x, y, -60, -30, 80, 20) ||
           nearSegment(x, y, 20, -20, 70, -20, 2.5) ||
           inRect(x, y, 50, -40, 40, 50) ||
           inEllipse(x, y, 90, -30, 20, 20);

  case 4: // LORRY
    return inEllipse(x, y, -80, 10, 30, 30) ||
           inEllipse(x, y, -30, 10, 30, 30) ||
           inEllipse(x, y, 70, 10, 30, 30) ||
           inRect(x, y, -100, -70, 140, 70) ||
           inRect(x, y, 40, -50, 50, 50) ||
           inRect(x, y, 65, -40, 25, 20);

  case 5: // CAR
    return inEllipse(x, y, -50, 15, 25, 25) ||
           inEllipse(x, y, 50, 15, 25, 25) ||
           inRect(x, y, -70, -20, 140, 30) ||
           inRect(x, y, -40, -45, 80, 30);

  case 6: // AEROPLANE
    return inEllipse(x, y, 0, 0, 160, 40) ||
           inTriangle(x, y, -20, -20, 20, -20, -40, -70) ||
           inTriangle(x, y, 20, 10, -20, 10, 0, 60);

  case 7: // BIRD
    return inEllipse(x, y, 0, 0, 60, 25) ||
           inTriangle(x, y, -10, 0, 10, 0, 0, -40) ||
           inTriangle(x, y, 30, -5, 30, 5, 45, 0);

  case 8: // SNAIL
    return inRect(x, y, -20, 10, 50, 10) ||
           nearSegment(x, y, 30, 10, 40, -10, 1.5) ||
           inEllipse(x, y, -10, -5, 40, 40);

  case 9: // TORTOISE
    return inEllipse(x, y, -25, 15, 15, 15) ||
           inEllipse(x, y, 25, 15, 15, 15) ||
           inEllipse(x, y, 40, 5, 20, 15) ||
           (y <= 15 &&
            inEllipse(x, y, 0, 15, 70, 50));

  case 10: // LEOPARD
    return inRect(x, y, -40, -20, 80, 25) ||
           inRect(x, y, -35, 0, 10, 30) ||
           inRect(x, y, 25, 0, 10, 30) ||
           inEllipse(x, y, 50, -25, 25, 25);

  case 11: // ELEPHANT
    return inRect(x, y, -50, -60, 100, 80) ||
           inRect(x, y, -45, 20, 20, 30) ||
           inRect(x, y, 25, 20, 20, 30) ||
           inEllipse(x, y, 60, -40, 50, 50) ||
           inRect(x, y, 75, -30, 15, 60);
  }

  return false;
}

// ==================================================
// CELL CONTAINMENT TEST
// ==================================================

boolean cellFullyInside(float gx, float gy, float step) {
  float x1 = gx;
  float y1 = gy;
  float x2 = gx + step;
  float y2 = gy + step;

  float xm = (x1 + x2) * 0.5;
  float ym = (y1 + y2) * 0.5;

  return isInsideEntity(x1, y1) &&
         isInsideEntity(x2, y1) &&
         isInsideEntity(x1, y2) &&
         isInsideEntity(x2, y2) &&
         isInsideEntity(xm, y1) &&
         isInsideEntity(xm, y2) &&
         isInsideEntity(x1, ym) &&
         isInsideEntity(x2, ym) &&
         isInsideEntity(xm, ym);
}

// ==================================================
// OBJECT GRID, VELOCITY VECTORS AND POSITION VECTORS
// ==================================================

void drawSubdividedVelocityVectors() {
  float step = gridCellSize;
  float half = step * 0.5;

  float globalOriginX = width * 0.10;
  float globalOriginY = roadY + roadHeight * 0.85;

  // Convert the fixed global reference into local coordinates.
  float localOx = (globalOriginX - entityX) / getEntityScale();
  float localOy = (globalOriginY - entityY) / getEntityScale();

  float arrowLength = map(
    speedKmh,
    0,
    maxSpeeds[currentScreen],
    0,
    65
  );

  arrowLength = constrain(arrowLength, 0, 65);

  for (float gx = -120; gx < 120; gx += step) {
    for (float gy = -100; gy < 100; gy += step) {

      if (!cellFullyInside(gx, gy, step)) {
        continue;
      }

      float cx = gx + half;
      float cy = gy + half;

      // Grid is attached to the object, not the world grid.
      if (showGrid) {
        stroke(255, 170, 0, 190);
        strokeWeight(0.65);
        noFill();
        rect(gx, gy, step, step);
      }

      if (showGrid || showVectors ||
          showPositionVectors || showXYLabels) {
        noStroke();
        fill(255, 200, 0);
        ellipse(cx, cy, 2.2, 2.2);
      }

      // Position vector from fixed screen reference point.
      if (showPositionVectors) {
        stroke(0, 210, 255, 180);
        strokeWeight(1.0);
        line(localOx, localOy, cx, cy);
      }

      // Rigid-body translational velocity.
      if (showVectors && speedKmh >= 0.05) {
        drawArrow(
          cx, cy,
          cx + arrowLength, cy,
          color(255, 165, 0),
          1.5
        );
      }

      // Sample point's global coordinates.
      if (showXYLabels) {
        float screenX = entityX + cx * getEntityScale();
        float screenY = entityY + cy * getEntityScale();

        float globalX = (screenX - globalOriginX) /
                        PIXELS_PER_METRE;

        float globalY = (globalOriginY - screenY) /
                        PIXELS_PER_METRE;

        noStroke();
        fill(255);
        textSize(4.5);

        text(
          "(" + nf(globalX, 0, 2) +
          ", " + nf(globalY, 0, 2) + ") m",
          cx + 2,
          cy - 3
        );
      }
    }
  }
}

// ==================================================
// ARROW DRAWING
// ==================================================

void drawArrow(float x1, float y1,
               float x2, float y2,
               int arrowColor, float sw) {
  stroke(arrowColor);
  strokeWeight(sw);

  line(x1, y1, x2, y2);

  float angle = atan2(y2 - y1, x2 - x1);
  float head = 3.0;

  line(
    x2, y2,
    x2 - head * cos(angle - PI / 6),
    y2 - head * sin(angle - PI / 6)
  );

  line(
    x2, y2,
    x2 - head * cos(angle + PI / 6),
    y2 - head * sin(angle + PI / 6)
  );
}

// ==================================================
// HEADLIGHT / REFERENCE VECTOR
// ==================================================

void drawRedHeadVector() {
  float localOx =
    (width * 0.10 - entityX) / getEntityScale();

  float localOy =
    (roadY + roadHeight * 0.85 - entityY)
    / getEntityScale();

  if (frameCount % 40 < 20) {
    stroke(255, 0, 0, 190);
    strokeWeight(1.5);

    line(localOx, localOy, hx, hy);

    fill(255, 100, 100);
    noStroke();
    textSize(7);

    text(
      nf(dist(localOx, localOy, hx, hy) /
         PIXELS_PER_METRE, 0, 1) + " m",
      (localOx + hx) * 0.5,
      (localOy + hy) * 0.5 - 5
    );
  }

  if (speedKmh >= 0.05) {
    float len = map(
      speedKmh,
      0,
      maxSpeeds[currentScreen],
      0,
      120
    );

    len = constrain(len, 0, 120);

    drawArrow(
      hx, hy, hx + len, hy,
      color(250, 50, 50), 2.5
    );
  }
}

// ==================================================
// TELEMETRY
// ==================================================

void drawHUD() {
  float panelW = min(310, width * 0.39);
  float panelH = 180;
  float panelX = width - panelW - 12;
  float panelY = 12;

  noStroke();
  fill(12, 23, 38, 220);
  rect(panelX, panelY, panelW, panelH, 12);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(17);

  text(
    entityNames[currentScreen] + " TELEMETRY",
    panelX + 12, panelY + 21
  );

  fill(180, 230, 255);
  textSize(12);

  text(
    "Speed: " + nf(speedKmh, 0, 2) + " km/h",
    panelX + 12, panelY + 47
  );

  text(
    "Distance travelled: " + nf(worldDistance, 0, 3) + " m",
    panelX + 12, panelY + 72
  );

  text(
    "Time: " + nf(elapsedTime, 0, 2) + " s",
    panelX + 12, panelY + 97
  );

  text(
    "Grid cell: " + nf(gridCellSize, 0, 1) + " units",
    panelX + 12, panelY + 122
  );

  float originX = width * 0.10;
  float objectGlobalX =
    (entityX - originX) / PIXELS_PER_METRE;

  text(
    "Screen-grid X: " + nf(objectGlobalX, 0, 2) + " m",
    panelX + 12, panelY + 147
  );

  text(
    "Grid: FIXED | Object: MOVING",
    panelX + 12, panelY + 168
  );

  textAlign(LEFT, CENTER);
}

// ==================================================
// OBJECT SCALE SLIDER
// ==================================================

void drawScaleSlider() {
  float sliderW = min(300, width * 0.40);
  float sliderX = (width - sliderW) * 0.5;
  float sliderY = height - 132;

  stroke(150);
  strokeWeight(5);
  line(sliderX, sliderY, sliderX + sliderW, sliderY);

  float knobX = sliderX +
    norm(scooterScale, 0.5, 4.0) * sliderW;

  noStroke();
  fill(draggingSlider ? color(255, 230, 80)
                      : color(255, 200, 0));

  ellipse(knobX, sliderY, 17, 17);

  fill(255);
  textSize(12);
  textAlign(CENTER, CENTER);
  text("OBJECT SIZE", width * 0.5, sliderY - 15);

  textAlign(LEFT, CENTER);
}

// ==================================================
// FOURTEEN TOUCH CONTROLS
// ==================================================

void drawControls() {
  String[] labels = {
    "BRAKE", "THROTTLE",
    paused ? "RESUME" : "PAUSE",
    showVectors ? "HIDE VEL" : "VELOCITY",
    showPositionVectors ? "HIDE POS" : "POS VECS",
    "RESET", "HEAD VEC",

    "NEXT >>",
    showGrid ? "GRID ON" : "GRID OFF",
    showWorldGrid ? "WORLD ON" : "WORLD OFF",
    showXYLabels ? "X,Y ON" : "X,Y OFF",
    "CELL -", "CELL +", "GRID INFO"
  };

  int[] colors = {
    color(190, 50, 50),
    color(40, 150, 80),
    color(60, 90, 140),
    color(100, 70, 140),
    color(0, 150, 200),
    color(90, 95, 105),
    color(200, 50, 50),

    color(255, 150, 0),
    color(140, 100, 30),
    color(40, 100, 140),
    color(100, 100, 100),
    color(80, 110, 140),
    color(80, 110, 140),
    color(70, 70, 90)
  };

  int perRow = 7;
  float gap = 5;
  float margin = 10;

  float bW = (width - 2 * margin -
              gap * (perRow - 1)) / perRow;

  float bH = 35;
  float y1 = height - 91;
  float y2 = height - 47;

  textSize(11);
  textAlign(CENTER, CENTER);

  for (int i = 0; i < labels.length; i++) {
    int row = i / perRow;
    int col = i % perRow;

    float bx = margin + col * (bW + gap);
    float by = row == 0 ? y1 : y2;

    noStroke();
    fill(colors[i]);
    rect(bx, by, bW, bH, 7);

    fill(255);
    text(
      labels[i],
      bx + bW * 0.5,
      by + bH * 0.5
    );
  }

  textAlign(LEFT, CENTER);
}

// ==================================================
// TOUCH INPUT
// ==================================================

void mousePressed() {
  float sliderW = min(300, width * 0.40);
  float sliderX = (width - sliderW) * 0.5;
  float sliderY = height - 132;

  float knobX = sliderX +
    norm(scooterScale, 0.5, 4.0) * sliderW;

  if (dist(mouseX, mouseY, knobX, sliderY) < 24 ||
      (mouseY > sliderY - 12 &&
       mouseY < sliderY + 12 &&
       mouseX >= sliderX &&
       mouseX <= sliderX + sliderW)) {
    draggingSlider = true;
    updateScaleFromTouch();
    return;
  }

  int perRow = 7;
  float gap = 5;
  float margin = 10;

  float bW = (width - 2 * margin -
              gap * (perRow - 1)) / perRow;

  float bH = 35;
  float y1 = height - 91;
  float y2 = height - 47;

  int row = -1;

  if (mouseY >= y1 && mouseY <= y1 + bH) {
    row = 0;
  } else if (mouseY >= y2 && mouseY <= y2 + bH) {
    row = 1;
  }

  if (row < 0) return;

  int col = int((mouseX - margin) / (bW + gap));

  if (col < 0 || col >= perRow) return;

  float bx = margin + col * (bW + gap);

  if (mouseX > bx + bW) return;

  int idx = row * perRow + col;

  switch (idx) {

  case 0: // BRAKE
    throttle = max(0, throttle - 0.35);
    break;

  case 1: // THROTTLE
    throttle = min(1, throttle + 0.20);
    break;

  case 2: // PAUSE / RESUME
    paused = !paused;
    break;

  case 3: // VELOCITY VECTORS
    showVectors = !showVectors;
    showHeadlightVector = false;
    break;

  case 4: // POSITION VECTORS
    showPositionVectors = !showPositionVectors;
    showHeadlightVector = false;
    break;

  case 5: // RESET
    resetSimulation();
    break;

  case 6: // HEADLIGHT VECTOR
    showHeadlightVector = !showHeadlightVector;

    if (showHeadlightVector) {
      showVectors = false;
      showPositionVectors = false;
    }
    break;

  case 7: // NEXT ENTITY
    currentScreen = (currentScreen + 1) % 12;
    resetSimulation();
    break;

  case 8: // OBJECT GRID
    showGrid = !showGrid;
    break;

  case 9: // STATIC WORLD GRID
    showWorldGrid = !showWorldGrid;
    break;

  case 10: // X,Y LABELS
    showXYLabels = !showXYLabels;
    break;

  case 11: // SMALLER CELLS
    gridCellSize = max(minCellSize, gridCellSize - 2);
    break;

  case 12: // LARGER CELLS
    gridCellSize = min(maxCellSize, gridCellSize + 2);
    break;

  case 13: // GRID INFO
    showGrid = true;
    showWorldGrid = true;
    showXYLabels = true;
    showVectors = true;
    showHeadlightVector = false;
    break;
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
  float sliderW = min(300, width * 0.40);
  float sliderX = (width - sliderW) * 0.5;

  float t = constrain(
    (mouseX - sliderX) / sliderW,
    0, 1
  );

  scooterScale = lerp(0.5, 4.0, t);
}

// ==================================================
// RESET
// ==================================================

void resetSimulation() {
  speedKmh = 0;
  targetSpeed = 0;
  worldDistance = 0;
  elapsedTime = 0;
  objectTravelX = 0;

  throttle = 0;
  paused = false;
  scooterScale = 2.0;

  initialEntityX = width * 0.20;
}
