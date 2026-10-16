/*
 MECHANICS VECTORS FOR ENGINEERS
 COMPLETE 3D VOXEL + MULTI-OBSERVER VELOCITY TRACKER
 Processing Java Mode / Android Mode (P3D)

 +X = right, +Y = mathematical up, +Z = toward camera.
 Position telemetry: metres.
 Velocity telemetry: metres/second.

 Educational procedural simulation; no built-in AI pose inference.
*/

final int MAX_OBSERVERS = 8;
final int ENTITY_COUNT = 12;
final int BUTTON_COUNT = 30;
final int BUTTON_COLS = 6;
final int BUTTON_ROWS = 5;
final int MAX_POINTS = 600;

final float PIXELS_PER_METRE = 16.0;
final float GRID_SPACING = 50.0;
final float MIN_CELL = 8.0;
final float MAX_CELL = 30.0;

String[] entityNames = {
  "WALKING HUMAN", "SCOOTER", "BICYCLE", "BULLOCK CART",
  "LORRY", "CAR", "AEROPLANE", "BIRD",
  "SNAIL", "TORTOISE", "LEOPARD", "ELEPHANT"
};

float[] maxSpeeds = {
  15, 90, 30, 15, 120, 180, 900, 60, 1, 3, 110, 40
};

int[] observerColors = {
  0xFF00A6FF, 0xFFFF4040, 0xFF20C878, 0xFFFFA020,
  0xFFB070FF, 0xFFFF55AA, 0xFF20D0D0, 0xFFFFFF60
};

float speedKmh = 0;
float throttle = 0.35;
float distanceM = 0;
float elapsed = 0;
float animationTime = 0;
float roadOffset = 0;

float objectScale = 1.5;
float cellSize = 16;

float entityX, entityY, entityZ, initialX;
float roadY, roadHeight;
float entityVX, entityVY, entityVZ;

float cameraYaw = 0.28;
float cameraElevation = 0.30;
float cameraDistance;

boolean paused = false;
boolean straightLine = false;
boolean showGrid = true;
boolean showCells = true;
boolean showPosition = true;
boolean showVelocity = true;
boolean showRelative = true;
boolean showCoordinates = true;
boolean showLabels = true;
boolean snapGrid = true;

boolean allVoxelComponents = false;
boolean allPositionVectors = false;
boolean allVoxelAxes = false;
boolean allResultants = true;

// Replaced placingOrigin with a D-Pad flag
boolean useDpad = false;
boolean draggingSlider = false;
boolean draggingCamera = false;

float lastX, lastY;

int currentEntity = 0;
int observerCount = 1;
int selectedObserver = 0;
int selectedPoint = 0;
int pointCount = 0;

PFont uiFont;
int skyColor, roadColor;

// Observer state
float[] ox = new float[MAX_OBSERVERS];
float[] oy = new float[MAX_OBSERVERS];
float[] oz = new float[MAX_OBSERVERS];

float[] ovx = new float[MAX_OBSERVERS];
float[] ovy = new float[MAX_OBSERVERS];
float[] ovz = new float[MAX_OBSERVERS];

boolean[] follows = new boolean[MAX_OBSERVERS];
boolean[] visible = new boolean[MAX_OBSERVERS];
boolean[] randomPath = new boolean[MAX_OBSERVERS];

String[] observerName = new String[MAX_OBSERVERS];
int[] pathType = new int[MAX_OBSERVERS];

float[] pcx = new float[MAX_OBSERVERS];
float[] pcy = new float[MAX_OBSERVERS];
float[] pcz = new float[MAX_OBSERVERS];

float[] pax = new float[MAX_OBSERVERS];
float[] pay = new float[MAX_OBSERVERS];
float[] paz = new float[MAX_OBSERVERS];

float[] pwx = new float[MAX_OBSERVERS];
float[] pwy = new float[MAX_OBSERVERS];
float[] pwz = new float[MAX_OBSERVERS];

float[] phx = new float[MAX_OBSERVERS];
float[] phy = new float[MAX_OBSERVERS];
float[] phz = new float[MAX_OBSERVERS];

// Voxel local coordinates
float[] lx = new float[MAX_POINTS];
float[] ly = new float[MAX_POINTS];
float[] lz = new float[MAX_POINTS];

// Voxel world-position history
float[] wxNow = new float[MAX_POINTS];
float[] wyNow = new float[MAX_POINTS];
float[] wzNow = new float[MAX_POINTS];

float[] wxPrev = new float[MAX_POINTS];
float[] wyPrev = new float[MAX_POINTS];
float[] wzPrev = new float[MAX_POINTS];

// Per-voxel velocity, metres/second
float[] vxPoint = new float[MAX_POINTS];
float[] vyPoint = new float[MAX_POINTS];
float[] vzPoint = new float[MAX_POINTS];

boolean voxelHistory = false;
boolean pointsDirty = true;

int cachedEntity = -1;
float cachedCell = -1;
float cachedScale = -1;

float[] projectedOX = new float[MAX_OBSERVERS];
float[] projectedOY = new float[MAX_OBSERVERS];

float selectedScreenX = -100;
float selectedScreenY = -100;


// ============================================================
// INITIALIZATION
// ============================================================

void settings() {
  fullScreen(P3D);
}

void setup() {
  orientation(LANDSCAPE);
  frameRate(30);
  smooth(2);

  uiFont = createFont("sans-serif", 16, true);
  textFont(uiFont);

  skyColor = color(145, 207, 245);
  roadColor = color(57, 61, 68);

  calculateLayout();

  entityX = initialX;
  entityZ = 0;

  updateEntityHeight();
  initObservers();
  rebuildDomainPoints();
}

void calculateLayout() {
  roadY = height * 0.62;
  roadHeight = height - roadY;
  initialX = width * 0.20;
  cameraDistance = max(width, height) * 1.55;
}

float buttonTop() {
  return height - BUTTON_ROWS * 36 - 8;
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

float sceneScale() {
  return max(0.55, min(width / 1000.0,
    height / 500.0)) * objectScale;
}

float bottomOffset() {
  switch (currentEntity) {
  case 0: return 46;
  case 1: return 20;
  case 2: return 22;
  case 3: return 31;
  case 4: return 30;
  case 5: return 27;
  case 6: return 58;
  case 7: return 23;
  case 8: return 24;
  case 9: return 27;
  case 10: return 31;
  default: return 51;
  }
}

void updateEntityHeight() {
  float base = roadY - bottomOffset() * sceneScale();

  if (straightLine) {
    entityY = base;
  } else {
    float frequency = currentEntity == 0 ? 8.0 : 1.4;
    float amount = currentEntity == 0 ? 3.5 : 2.0;

    entityY = base
      - sin(animationTime * frequency)
      * amount * sceneScale();
  }
}


// ============================================================
// OBSERVERS
// ============================================================

void initObservers() {
  observerCount = 1;
  selectedObserver = 0;

  for (int i = 0; i < MAX_OBSERVERS; i++) {
    ox[i] = width * (0.12 + 0.07 * i);
    oy[i] = roadY - 70;
    oz[i] = (i % 2 == 0) ? 0 : 70;

    ovx[i] = ovy[i] = ovz[i] = 0;

    follows[i] = false;
    visible[i] = true;
    randomPath[i] = false;

    observerName[i] = "OBSERVER " + (i + 1);
    pathType[i] = 0;

    pcx[i] = ox[i];
    pcy[i] = oy[i];
    pcz[i] = oz[i];

    pax[i] = pay[i] = paz[i] = 0;

    pwx[i] = pwy[i] = pwz[i] = 1;

    phx[i] = phy[i] = phz[i] = 0;
  }

  ox[0] = entityX;
  oy[0] = entityY;
  oz[0] = entityZ;
}

void addObserver() {
  if (observerCount >= MAX_OBSERVERS) return;

  int i = observerCount++;

  ox[i] = constrain(entityX + 70 * i, 30, width - 30);
  oy[i] = constrain(entityY - 35, 45, roadY - 10);
  oz[i] = (i % 2 == 0) ? -60 : 60;

  ovx[i] = ovy[i] = ovz[i] = 0;

  follows[i] = false;
  visible[i] = true;
  randomPath[i] = false;

  observerName[i] = "OBSERVER " + (i + 1);
  pathType[i] = 0;

  pcx[i] = ox[i];
  pcy[i] = oy[i];
  pcz[i] = oz[i];

  pax[i] = pax[i] = paz[i] = 0;
  pwx[i] = pwy[i] = pwz[i] = 1;
  phx[i] = phy[i] = phz[i] = 0;

  selectedObserver = i;
  useDpad = false;
}

void nextObserver() {
  selectedObserver = (selectedObserver + 1) % observerCount;
  useDpad = false;
}

void prevObserver() {
  selectedObserver =
    (selectedObserver - 1 + observerCount) % observerCount;

  useDpad = false;
}

void deleteObserver() {
  if (selectedObserver == 0 || observerCount <= 1) return;

  for (int i = selectedObserver; i < observerCount - 1; i++) {
    ox[i] = ox[i + 1];
    oy[i] = oy[i + 1];
    oz[i] = oz[i + 1];

    ovx[i] = ovx[i + 1];
    ovy[i] = ovy[i + 1];
    ovz[i] = ovz[i + 1];

    follows[i] = follows[i + 1];
    visible[i] = visible[i + 1];
    randomPath[i] = randomPath[i + 1];

    observerName[i] = observerName[i + 1];

    pathType[i] = pathType[i + 1];

    pcx[i] = pcx[i + 1];
    pcy[i] = pcy[i + 1];
    pcz[i] = pcz[i + 1];

    pax[i] = pax[i + 1];
    pay[i] = pay[i + 1];
    paz[i] = paz[i + 1];

    pwx[i] = pwx[i + 1];
    pwy[i] = pwy[i + 1];
    pwz[i] = pwz[i + 1];

    phx[i] = phx[i + 1];
    phy[i] = phy[i + 1];
    phz[i] = phz[i + 1];
  }

  observerCount--;
  selectedObserver = min(selectedObserver, observerCount - 1);
  useDpad = false;
}


// ============================================================
// RANDOM OBSERVER PATHS
// ============================================================

void assignRandomPath(int i) {
  follows[i] = false;
  randomPath[i] = true;
  pathType[i] = int(random(4));

  pcx[i] = constrain(ox[i], width * 0.1, width * 0.9);
  pcy[i] = constrain(oy[i], 80, roadY - 30);
  pcz[i] = constrain(oz[i], -100, 100);

  pax[i] = min(random(width * 0.04, width * 0.14),
    min(pcx[i] - width * 0.04, width * 0.96 - pcx[i]));

  pay[i] = min(random(15, 55),
    min(pcy[i] - 45, roadY - 15 - pcy[i]));

  paz[i] = min(random(20, 75),
    min(pcz[i] + 150, 150 - pcz[i]));

  pax[i] = max(0, pax[i]);
  pay[i] = max(0, pay[i]);
  paz[i] = max(0, paz[i]);

  pwx[i] = random(0.4, 1.2);
  pwy[i] = random(0.4, 1.1);
  pwz[i] = random(0.3, 0.9);

  phx[i] = random(TWO_PI);
  phy[i] = random(TWO_PI);
  phz[i] = random(TWO_PI);
}

void updateRandomObserver(int i, float dt) {
  float t = animationTime;

  float x = pcx[i];
  float y = pcy[i];
  float z = pcz[i];

  if (pathType[i] == 0) {
    x += pax[i] * cos(pwx[i] * t + phx[i]);
    y += pay[i] * sin(pwy[i] * t + phy[i]);
    z += paz[i] * cos(pwz[i] * t + phz[i]);
  } else if (pathType[i] == 1) {
    x += pax[i] * sin(pwx[i] * t + phx[i]);
    y += pay[i] * sin(pwy[i] * t + phy[i]);
    z += paz[i] * sin(pwz[i] * t + phz[i]);
  } else if (pathType[i] == 2) {
    x += pax[i] * sin(pwx[i] * t + phx[i]);
    y += pay[i] * sin(2 * pwy[i] * t + phy[i]);
    z += paz[i] * sin(pwz[i] * t + phz[i]);
  } else {
    x += pax[i] * cos(pwx[i] * t + phx[i]);
    y += pay[i] * cos(2 * pwy[i] * t + phy[i]);
    z += paz[i] * sin(pwz[i] * t + phz[i]);
  }

  float oldX = ox[i];
  float oldY = oy[i];
  float oldZ = oz[i];

  ox[i] = constrain(x, width * 0.04, width * 0.96);
  oy[i] = constrain(y, 45, roadY - 10);
  oz[i] = constrain(z, -150, 150);

  if (dt > 0) {
    ovx[i] = (ox[i] - oldX) / PIXELS_PER_METRE / dt;
    ovy[i] = -(oy[i] - oldY) / PIXELS_PER_METRE / dt;
    ovz[i] = (oz[i] - oldZ) / PIXELS_PER_METRE / dt;
  }
}


// ============================================================
// MAIN LOOP
// ============================================================

void draw() {
  calculateLayout();
  updateSimulation();
  ensureDomainPoints();
  updateVoxelKinematics();

  background(skyColor);
  setCamera();

  ambientLight(120, 120, 120);
  directionalLight(210, 210, 210, -0.35, -0.65, -1.0);

  drawWorldGrid();
  drawRoad();
  drawObservers();
  drawEntity();

  drawPositionVectors();
  drawVoxelVelocityComponents();
  drawVoxelAxes();
  drawVoxelResultants();
  drawSelectedVectors();
  drawRelativeVectors();

  drawOverlay();
}

void setCamera() {
  float tx = width * 0.50;
  float ty = roadY * 0.69;
  float d = cameraDistance;

  float ex = tx + sin(cameraYaw) * d * cos(cameraElevation);
  float ey = ty - sin(cameraElevation) * d;
  float ez = cos(cameraYaw) * d * cos(cameraElevation);

  perspective(PI / 3.0, float(width) / max(1, height), 5, d * 5.5);
  camera(ex, ey, ez, tx, ty, 0, 0, 1, 0);
}

void updateSimulation() {
  float dt = min(0.05, 1.0 / max(frameRate, 1));
  float oldY = entityY;

  if (!paused) {
    animationTime += dt;
    elapsed += dt;

    float target = throttle * maxSpeeds[currentEntity];

    speedKmh = lerp(speedKmh, target, min(1.0, 0.8 * dt));

    float speedMS = speedKmh / 3.6;
    float displacement = speedMS * dt;

    distanceM += displacement;
    roadOffset += displacement * PIXELS_PER_METRE;

    float wrap = max(width, 1) * 0.72;

    if (roadOffset >= wrap) {
      roadOffset %= wrap;
    }

    entityX = initialX + roadOffset;
    updateEntityHeight();

    entityVX = speedMS;

    entityVY = straightLine ? 0
      : -((entityY - oldY) / PIXELS_PER_METRE) / dt;

    entityVZ = 0;
  } else {
    entityVX = 0;
    entityVY = 0;
    entityVZ = 0;
  }

  for (int i = 0; i < observerCount; i++) {
    if (follows[i]) {
      ox[i] = entityX;
      oy[i] = entityY;
      oz[i] = entityZ;

      ovx[i] = entityVX;
      ovy[i] = entityVY;
      ovz[i] = entityVZ;
    } else if (randomPath[i] && !paused) {
      updateRandomObserver(i, dt);
    } else if (paused) {
      ovx[i] = ovy[i] = ovz[i] = 0;
    }
  }
}


// ============================================================
// VECTOR MATH
// ============================================================

float relVX(int i) {
  return entityVX - ovx[i];
}

float relVY(int i) {
  return entityVY - ovy[i];
}

float relVZ(int i) {
  return entityVZ - ovz[i];
}

float mag3(float x, float y, float z) {
  return sqrt(x*x + y*y + z*z);
}

float angle3(float x, float z) {
  return (degrees(atan2(z, x)) % 360 + 360) % 360;
}

float elev3(float x, float y, float z) {
  return degrees(atan2(y, sqrt(x*x + z*z)));
}

float vectorScale(float x, float y, float z) {
  float m = mag3(x, y, z);
  return m < 0.001 ? 0 : min(4.0, 100.0 / m);
}

float wx(int i) {
  return entityX + lx[i] * sceneScale();
}

float wy(int i) {
  return entityY + ly[i] * sceneScale();
}

float wz(int i) {
  return entityZ + lz[i] * sceneScale();
}


// ============================================================
// PER-VOXEL VELOCITY HISTORY
// ============================================================

void updateVoxelKinematics() {
  float dt = min(0.05, 1.0 / max(frameRate, 1));

  for (int i = 0; i < pointCount; i++) {
    wxNow[i] = wx(i);
    wyNow[i] = wy(i);
    wzNow[i] = wz(i);

    if (voxelHistory && !paused && dt > 0) {
      vxPoint[i] =
        (wxNow[i] - wxPrev[i]) / PIXELS_PER_METRE / dt;

      vyPoint[i] =
        -(wyNow[i] - wyPrev[i]) / PIXELS_PER_METRE / dt;

      vzPoint[i] =
        (wzNow[i] - wzPrev[i]) / PIXELS_PER_METRE / dt;
    } else if (voxelHistory) {
      vxPoint[i] = 0;
      vyPoint[i] = 0;
      vzPoint[i] = 0;
    } else {
      vxPoint[i] = entityVX;
      vyPoint[i] = entityVY;
      vzPoint[i] = entityVZ;
    }

    wxPrev[i] = wxNow[i];
    wyPrev[i] = wyNow[i];
    wzPrev[i] = wzNow[i];
  }

  voxelHistory = true;
}


// ============================================================
// 3D ARROW DRAWING
// ============================================================

void drawArrow(PVector a, PVector b, int c, float sw) {
  stroke(c);
  strokeWeight(sw);

  line(a.x, a.y, a.z, b.x, b.y, b.z);

  PVector dir = PVector.sub(b, a);
  float len = dir.mag();

  if (len < 3) return;

  dir.normalize();

  PVector helper = abs(dir.y) < 0.88
    ? new PVector(0, 1, 0)
    : new PVector(1, 0, 0);

  PVector side = dir.cross(helper);

  if (side.magSq() < 0.0001) {
    side = new PVector(0, 0, 1);
  }

  side.normalize();

  float head = min(9, max(4, len * 0.20));

  PVector base = PVector.sub(b, PVector.mult(dir, head));

  PVector p1 = PVector.add(base, PVector.mult(side, head * 0.42));
  PVector p2 = PVector.sub(base, PVector.mult(side, head * 0.42));

  line(b.x, b.y, b.z, p1.x, p1.y, p1.z);
  line(b.x, b.y, b.z, p2.x, p2.y, p2.z);
}


// ============================================================
// ROAD AND WORLD GRID
// ============================================================

void drawRoad() {
  noStroke();
  fill(roadColor);

  beginShape(QUADS);
  vertex(-width * 0.65, roadY, -280);
  vertex(width * 1.65, roadY, -280);
  vertex(width * 1.65, roadY, 280);
  vertex(-width * 0.65, roadY, 280);
  endShape();

  stroke(245, 231, 164);
  strokeWeight(3);

  line(-width * 0.65, roadY - 1, -115,
    width * 1.65, roadY - 1, -115);

  line(-width * 0.65, roadY - 1, 115,
    width * 1.65, roadY - 1, 115);

  stroke(255, 245, 200);

  for (float x = -width * 0.65; x < width * 1.65; x += 65) {
    line(x, roadY - 1, 0, x + 34, roadY - 1, 0);
  }
}

void drawWorldGrid() {
  if (!showGrid) return;

  stroke(25, 65, 100, 75);
  strokeWeight(1);

  for (float x = -width; x <= width * 2; x += GRID_SPACING) {
    line(x, roadY - 1, -275, x, roadY - 1, 275);
  }

  for (float z = -250; z <= 250; z += GRID_SPACING) {
    line(-width, roadY - 1, z, width * 2, roadY - 1, z);
  }

  stroke(28, 68, 100, 45);

  for (float x = 0; x <= width; x += GRID_SPACING) {
    line(x, 35, -235, x, roadY, -235);
  }

  for (float y = 50; y <= roadY; y += GRID_SPACING) {
    line(0, y, -235, width, y, -235);
  }
}


// ============================================================
// ENTITY DRAWING HELPERS
// ============================================================

void box3(float x, float y, float z,
  float w, float h, float d, int c) {

  pushMatrix();
  translate(x, y, z);
  noStroke();
  fill(c);
  box(max(0.5, w), max(0.5, h), max(0.5, d));
  popMatrix();
}

void ell3(float x, float y, float z,
  float w, float h, float d, int c) {

  pushMatrix();
  translate(x, y, z);
  scale(max(0.5, w), max(0.5, h), max(0.5, d));
  noStroke();
  fill(c);
  sphereDetail(7);
  sphere(0.5);
  popMatrix();
}

void limb3(float x1, float y1, float z1,
  float x2, float y2, float z2,
  float thick, float depth, int c) {

  float dx = x2 - x1;
  float dy = y2 - y1;
  float dz = z2 - z1;

  float len = sqrt(dx*dx + dy*dy + dz*dz);

  pushMatrix();

  translate((x1+x2)*0.5, (y1+y2)*0.5, (z1+z2)*0.5);
  rotateZ(atan2(dy, dx) + HALF_PI);

  noStroke();
  fill(c);
  box(thick, len, depth);

  popMatrix();
}

void wheel(float x, float y, float z, float r) {
  ell3(x, y, z, r*2, r*2, max(5, r*0.38), color(25, 28, 31));
  ell3(x, y, z+r*0.2, r*0.8, r*0.8, 3, color(180));
}

void drawEntity() {
  pushMatrix();

  translate(entityX, entityY, entityZ);
  scale(sceneScale());

  drawModel();

  if (showCells) {
    drawVoxels();
  }

  if (pointCount > 0) {
    noStroke();
    fill(255, 20, 30);

    pushMatrix();
    translate(lx[selectedPoint], ly[selectedPoint], lz[selectedPoint]);
    sphereDetail(6);
    sphere(4);
    popMatrix();
  }

  popMatrix();
}

void drawModel() {
  float g = straightLine ? 0 : sin(animationTime * 8) * 0.36;

  switch (currentEntity) {

  case 0:
    ell3(0, -63, 0, 27, 30, 23, color(214, 169, 135));
    box3(0, -25, 0, 28, 43, 20, color(35, 102, 185));

    limb3(-14, -39, 0, -26-g*7, -9, 0, 9, 10, color(214,169,135));
    limb3(14, -39, 0, 26+g*7, -9, 0, 9, 10, color(214,169,135));

    limb3(-7, -7, 0, -12-g*17, 20, 0, 11, 12, color(36,42,58));
    limb3(-12-g*17, 20, 0, -16-g*23, 43, 2, 10, 11, color(45,48,56));

    limb3(7, -7, 0, 12+g*17, 20, 0, 11, 12, color(36,42,58));
    limb3(12+g*17, 20, 0, 16+g*23, 43, 2, 10, 11, color(45,48,56));
    break;

  case 1:
    wheel(-40, 0, 0, 17);
    wheel(40, 0, 0, 17);
    box3(0, -21, 0, 84, 17, 18, color(190,45,45));
    box3(-17, -37, 0, 34, 8, 18, color(28,30,34));
    limb3(25, -28, 0, 35, -49, 0, 5, 5, color(155));
    break;

  case 2:
    wheel(-40, 0, 0, 20);
    wheel(40, 0, 0, 20);

    stroke(230);
    strokeWeight(4);

    line(-40, 0, 0, -13, -30, 0);
    line(-13, -30, 0, 40, 0, 0);
    line(40, 0, 0, 9, -30, 0);
    line(9, -30, 0, -13, -30, 0);
    line(-13, -30, 0, -23, -39, 0);
    line(9, -30, 0, 18, -43, 0);
    break;

  case 3:
    wheel(-35, 7, -17, 24);
    wheel(-35, 7, 17, 24);
    box3(-10, -20, 0, 86, 12, 54, color(125,78,42));
    box3(-12, -38, 0, 77, 25, 49, color(155,105,57));
    ell3(60, -13, 0, 56, 31, 32, color(125,83,47));
    ell3(85, -28, 0, 27, 24, 24, color(155,111,72));
    break;

  case 4:
    for (int z = -1; z <= 1; z += 2) {
      wheel(-73, 8, z*15, 17);
      wheel(-25, 8, z*15, 17);
      wheel(64, 8, z*15, 17);
    }

    box3(-25, -32, 0, 95, 54, 50, color(178,47,45));
    box3(62, -27, 0, 58, 65, 48, color(42,93,155));
    box3(65, -43, 0, 37, 22, 50, color(95,177,213));
    break;

  case 5:
    for (int z = -1; z <= 1; z += 2) {
      wheel(-49, 11, z*20, 14);
      wheel(47, 11, z*20, 14);
    }

    box3(0, -13, 0, 139, 30, 47, color(45,150,198));
    box3(-7, -36, 0, 72, 25, 39, color(64,174,215));
    break;

  case 6:
    ell3(0, -7, 0, 150, 22, 24, color(210,215,221));
    box3(-4, -8, 0, 32, 6, 178, color(175,180,188));
    box3(-49, -10, 0, 28, 5, 52, color(185,190,198));
    box3(61, -4, 0, 18, 5, 35, color(190,195,202));
    break;

  case 7:
    ell3(0, 0, 0, 48, 24, 27, color(90,95,105));
    ell3(23, -10, 0, 22, 19, 19, color(105,111,119));
    limb3(39, -8, 0, 50, -5, 0, 5, 5, color(240,169,32));
    break;

  case 8:
    ell3(0, 1, 0, 66, 17, 27, color(145,190,100));
    ell3(-7, -13, 0, 42, 42, 34, color(170,117,74));
    ell3(28, -12, 0, 18, 22, 19, color(184,194,113));
    break;

  case 9:
    ell3(0, -3, 0, 73, 35, 48, color(100,146,75));
    ell3(0, -18, 0, 58, 36, 42, color(105,125,61));
    ell3(43, -1, 0, 21, 18, 20, color(113,161,83));

    for (int x = -1; x <= 1; x += 2) {
      for (int z = -1; z <= 1; z += 2) {
        ell3(x*25, 13, z*17, 17, 15, 15, color(94,144,66));
      }
    }
    break;

  case 10:
    ell3(0, -17, 0, 86, 31, 35, color(210,167,61));
    ell3(48, -25, 0, 30, 27, 29, color(220,178,70));

    limb3(-29,-4,-11,-35,23,-11,12,12,color(208,167,58));
    limb3(-9,-4,11,-7,23,11,12,12,color(208,167,58));
    limb3(25,-4,-11,30,23,-11,12,12,color(208,167,58));
    limb3(37,-4,11,42,23,11,12,12,color(208,167,58));
    break;

  case 11:
    ell3(0, -10, 0, 92, 75, 57, color(127,132,138));
    ell3(49, -30, 0, 43, 44, 45, color(139,145,150));

    limb3(62,-16,0,66,16,0,16,17,color(125,130,136));
    limb3(-34,10,-17,-35,43,-17,17,17,color(117,123,130));
    limb3(-6,10,17,-5,43,17,17,17,color(117,123,130));
    limb3(24,10,-17,28,43,-17,17,17,color(117,123,130));
    limb3(35,10,17,39,43,17,17,17,color(117,123,130));
    break;
  }
}


// ============================================================
// ENTITY OCCUPANCY TESTS FOR VOXELS
// ============================================================

boolean inBox(float x,float y,float z,
  float a,float b,float c,float d,float e,float f) {

  return x >= a && x <= d
      && y >= b && y <= e
      && z >= c && z <= f;
}

boolean inEll(float x,float y,float z,
  float cx,float cy,float cz,float rx,float ry,float rz) {

  float a = (x-cx) / max(0.001, rx);
  float b = (y-cy) / max(0.001, ry);
  float c = (z-cz) / max(0.001, rz);

  return a*a + b*b + c*c <= 1.0;
}

boolean insideEntity(float x,float y,float z) {
  switch (currentEntity) {

  case 0:
    return inEll(x,y,z,0,-63,0,14,15,12)
      || inBox(x,y,z,-15,-47,-10,15,-4,10)
      || inBox(x,y,z,-13,-10,-6,-2,45,6)
      || inBox(x,y,z,2,-10,-6,13,45,6)
      || inBox(x,y,z,-29,-42,-7,-9,-4,7)
      || inBox(x,y,z,9,-42,-7,29,-4,7);

  case 1:
    return inEll(x,y,z,-40,0,0,18,18,8)
      || inEll(x,y,z,40,0,0,18,18,8)
      || inBox(x,y,z,-45,-31,-10,43,-10,10)
      || inBox(x,y,z,-30,-43,-9,2,-33,9);

  case 2:
    return inEll(x,y,z,-40,0,0,20,20,7)
      || inEll(x,y,z,40,0,0,20,20,7)
      || inBox(x,y,z,-25,-48,-4,25,-25,4)
      || inBox(x,y,z,-43,-3,-3,43,3,3);

  case 3:
    return inEll(x,y,z,-35,7,0,24,24,7)
      || inBox(x,y,z,-55,-44,-25,32,-7,25)
      || inEll(x,y,z,60,-13,0,28,16,16)
      || inEll(x,y,z,84,-27,0,13,12,12);

  case 4:
    return inBox(x,y,z,-73,-59,-25,14,-5,25)
      || inBox(x,y,z,32,-59,-24,91,5,24)
      || inBox(x,y,z,49,-54,-25,82,-32,25)
      || inEll(x,y,z,-73,8,-15,17,17,8)
      || inEll(x,y,z,-25,8,-15,17,17,8)
      || inEll(x,y,z,64,8,-15,17,17,8);

  case 5:
    return inBox(x,y,z,-70,-28,-24,70,4,24)
      || inBox(x,y,z,-43,-48,-20,30,-22,20)
      || inEll(x,y,z,-49,11,-20,14,14,8)
      || inEll(x,y,z,47,11,20,14,14,8);

  case 6:
    return inEll(x,y,z,0,-7,0,75,11,12)
      || inBox(x,y,z,-20,-12,-89,15,-4,89)
      || inBox(x,y,z,-62,-13,-27,-36,-7,27)
      || inBox(x,y,z,50,-8,-18,70,0,18);

  case 7:
    return inEll(x,y,z,0,0,0,25,12,13)
      || inEll(x,y,z,23,-10,0,11,10,9)
      || inBox(x,y,z,-20,-16,-19,15,-1,19);

  case 8:
    return inEll(x,y,z,0,1,0,33,9,13)
      || inEll(x,y,z,-7,-13,0,21,21,17)
      || inEll(x,y,z,28,-12,0,9,11,9);

  case 9:
    return inEll(x,y,z,0,-3,0,36,17,24)
      || inEll(x,y,z,0,-18,0,29,18,21)
      || inEll(x,y,z,43,-1,0,11,9,10);

  case 10:
    return inEll(x,y,z,0,-17,0,43,15,17)
      || inEll(x,y,z,48,-25,0,15,14,14)
      || inBox(x,y,z,-40,-8,-18,-20,25,-5)
      || inBox(x,y,z,18,-8,-18,40,25,-5);

  case 11:
    return inEll(x,y,z,0,-10,0,46,38,28)
      || inEll(x,y,z,49,-30,0,21,22,22)
      || inBox(x,y,z,55,-18,-8,74,14,8)
      || inBox(x,y,z,-42,0,-25,-25,43,-8)
      || inBox(x,y,z,-14,0,8,3,43,25);
  }

  return false;
}

void ensureDomainPoints() {
  if (pointsDirty
    || cachedEntity != currentEntity
    || abs(cachedCell - cellSize) > 0.001
    || abs(cachedScale - sceneScale()) > 0.001) {

    rebuildDomainPoints();
  }
}

void rebuildDomainPoints() {
  pointCount = 0;

  float s = max(MIN_CELL, cellSize);

  for (float x = -115; x <= 115 && pointCount < MAX_POINTS; x += s) {
    for (float y = -88; y <= 62 && pointCount < MAX_POINTS; y += s) {
      for (float z = -42; z <= 42 && pointCount < MAX_POINTS; z += s) {

        if (insideEntity(x, y, z)) {
          lx[pointCount] = x;
          ly[pointCount] = y;
          lz[pointCount] = z;
          pointCount++;
        }
      }
    }
  }

  selectedPoint = pointCount > 0
    ? constrain(selectedPoint, 0, pointCount - 1) : 0;

  cachedEntity = currentEntity;
  cachedCell = cellSize;
  cachedScale = sceneScale();

  pointsDirty = false;
  voxelHistory = false;
}

void drawVoxels() {
  noStroke();

  float s = max(3, cellSize * 0.84);

  for (int i = 0; i < pointCount; i++) {
    pushMatrix();

    translate(lx[i], ly[i], lz[i]);
    fill(255, 168, 0, 74);
    box(s);

    popMatrix();
  }
}


// ============================================================
// OBSERVER AXES AND VECTORS
// ============================================================

void drawObservers() {
  for (int i = 0; i < observerCount; i++) {
    if (!visible[i]) continue;

    float x = ox[i];
    float y = oy[i];
    float z = oz[i];

    float ex = width * 0.5;
    float ey = height * 0.35;
    float ez = 180;

    drawArrow(
      new PVector(x-ex,y,z),
      new PVector(x+ex,y,z),
      color(245,70,70,210),
      i == selectedObserver ? 2 : 1
    );

    drawArrow(
      new PVector(x,y+ey,z),
      new PVector(x,max(8,y-ey),z),
      color(65,220,100,220),
      i == selectedObserver ? 2 : 1
    );

    drawArrow(
      new PVector(x,y,z-ez),
      new PVector(x,y,z+ez),
      color(70,145,255,220),
      i == selectedObserver ? 2 : 1
    );

    noStroke();
    fill(observerColors[i]);

    pushMatrix();
    translate(x,y,z);
    sphereDetail(6);
    sphere(i == selectedObserver ? 8 : 5);
    popMatrix();

    projectedOX[i] = screenX(x,y,z);
    projectedOY[i] = screenY(x,y,z);
  }
}

void drawRelativeVectors() {
  if (!showRelative) return;

  for (int i = 0; i < observerCount; i++) {
    if (!visible[i]) continue;

    float vx = relVX(i);
    float vy = relVY(i);
    float vz = relVZ(i);

    float s = vectorScale(vx,vy,vz);

    PVector a = new PVector(
      ox[i], oy[i]-35-i*5, oz[i]
    );

    PVector b = new PVector(
      a.x + vx*s,
      a.y - vy*s,
      a.z + vz*s
    );

    drawArrow(a,b,observerColors[i],
      i == selectedObserver ? 2.5 : 1.2);
  }
}

void drawPositionVectors() {
  if (!showPosition && !allPositionVectors) return;

  PVector origin = new PVector(
    ox[selectedObserver],
    oy[selectedObserver],
    oz[selectedObserver]
  );

  if (allPositionVectors) {
    for (int i = 0; i < pointCount; i++) {
      PVector p = new PVector(wx(i),wy(i),wz(i));

      drawArrow(origin,p,color(0,118,255,90),
        i == selectedPoint ? 2.5 : 0.8);
    }
  }
}

void drawVoxelVelocityComponents() {
  if (!showVelocity || !allVoxelComponents) return;

  for (int i = 0; i < pointCount; i++) {
    PVector p = new PVector(wx(i),wy(i),wz(i));

    float s = vectorScale(
      vxPoint[i],vyPoint[i],vzPoint[i]
    );

    // X component: orange
    drawArrow(p,
      new PVector(p.x+vxPoint[i]*s,p.y,p.z),
      color(255,138,0,185),0.9);

    // Y component: green
    drawArrow(p,
      new PVector(p.x,p.y-vyPoint[i]*s,p.z),
      color(20,190,80,185),0.9);

    // Z component: blue
    drawArrow(p,
      new PVector(p.x,p.y,p.z+vzPoint[i]*s),
      color(45,120,255,185),0.9);
  }
}

void drawVoxelAxes() {
  if (!showVelocity || !allVoxelAxes) return;

  float n = max(5,min(12,cellSize*0.6));

  for (int i = 0; i < pointCount; i++) {
    PVector p = new PVector(wx(i),wy(i),wz(i));

    drawArrow(p,new PVector(p.x+n,p.y,p.z),
      color(255,65,65,200),0.8);

    drawArrow(p,new PVector(p.x,p.y-n,p.z),
      color(65,225,95,200),0.8);

    drawArrow(p,new PVector(p.x,p.y,p.z+n),
      color(65,125,255,200),0.8);
  }
}

void drawVoxelResultants() {
  if (!showVelocity || !allResultants) return;

  for (int i = 0; i < pointCount; i++) {
    PVector p = new PVector(wx(i),wy(i),wz(i));

    float s = vectorScale(
      vxPoint[i],vyPoint[i],vzPoint[i]
    );

    PVector end = new PVector(
      p.x + vxPoint[i]*s,
      p.y - vyPoint[i]*s,
      p.z + vzPoint[i]*s
    );

    drawArrow(p,end,
      color(0,90,90,i==selectedPoint?255:145),
      i==selectedPoint?2.8:1);
  }
}

void drawSelectedVectors() {
  if (pointCount <= 0) return;

  int i = selectedPoint;

  PVector p = new PVector(wx(i),wy(i),wz(i));

  selectedScreenX = screenX(p.x,p.y,p.z);
  selectedScreenY = screenY(p.x,p.y,p.z);

  PVector origin = new PVector(
    ox[selectedObserver],
    oy[selectedObserver],
    oz[selectedObserver]
  );

  if (showPosition && !allPositionVectors) {
    drawArrow(origin,p,color(0,110,255),2.5);
  }

  if (showVelocity) {
    float s = vectorScale(
      vxPoint[i],vyPoint[i],vzPoint[i]
    );

    drawArrow(p,
      new PVector(p.x+vxPoint[i]*s,p.y,p.z),
      color(255,145,0),2.3);

    drawArrow(p,
      new PVector(p.x,p.y-vyPoint[i]*s,p.z),
      color(30,190,80),2.3);

    drawArrow(p,
      new PVector(p.x,p.y,p.z+vzPoint[i]*s),
      color(55,120,255),2.3);

    drawArrow(p,
      new PVector(
        p.x+vxPoint[i]*s,
        p.y-vyPoint[i]*s,
        p.z+vzPoint[i]*s
      ),
      color(10,75,75),3);
  }
}


// ============================================================
// HUD AND CONTROL PANEL
// ============================================================

void drawOverlay() {
  camera();
  noLights();
  hint(DISABLE_DEPTH_TEST);

  drawHUD();
  drawControls();
  drawSlider();
  drawDPad();

  hint(ENABLE_DEPTH_TEST);
}

void drawHUD() {
  float x = 10;
  float y = 10;
  float w = min(410,width*0.48);
  float h = 200;

  noStroke();
  fill(10,22,38,225);
  rect(x,y,w,h,8);

  fill(255);
  textAlign(LEFT,CENTER);
  textSize(12);

  text("3D DYNAMIC VECTOR TELEMETRY",x+10,y+14);

  fill(190,230,255);
  textSize(10);

  text("Entity: "+entityNames[currentEntity],x+10,y+31);

  text("Motion: "+(straightLine?"STRAIGHT":"GAIT / BOB"),
    x+10,y+46);

  text("Speed: "+nf(speedKmh,0,2)+" km/h",
    x+10,y+61);

  text("Absolute V: ("+
    nf(entityVX,0,2)+", "+
    nf(entityVY,0,2)+", "+
    nf(entityVZ,0,2)+") m/s",
    x+10,y+76);

  text("Distance: "+nf(distanceM,0,2)+" m | Time: "+
    nf(elapsed,0,2)+" s",x+10,y+91);

  text("Observers: "+observerCount+"/"+MAX_OBSERVERS+
    " | Voxels: "+pointCount,x+10,y+106);

  float vx = relVX(selectedObserver);
  float vy = relVY(selectedObserver);
  float vz = relVZ(selectedObserver);

  text("Relative V: ("+
    nf(vx,0,2)+", "+
    nf(vy,0,2)+", "+
    nf(vz,0,2)+") m/s",
    x+10,y+121);

  text("|Vrel| = "+nf(mag3(vx,vy,vz),0,2)+" m/s",
    x+10,y+136);

  if (pointCount > 0) {
    int i = selectedPoint;

    text("Voxel V: ("+
      nf(vxPoint[i],0,2)+", "+
      nf(vyPoint[i],0,2)+", "+
      nf(vzPoint[i],0,2)+") m/s",
      x+10,y+151);
  }

  text("XYZ COMPONENTS: "+(allVoxelComponents?"ON":"OFF")+
    " | AXES: "+(allVoxelAxes?"ON":"OFF"),
    x+10,y+166);

  text("RESULTANTS: "+(allResultants?"ON":"OFF")+
    " | GRID: "+(showGrid?"ON":"OFF"),
    x+10,y+181);
}

void drawSlider() {
  float x = sliderX();
  float y = sliderY();
  float w = sliderWidth();

  stroke(150);
  strokeWeight(4);
  line(x,y,x+w,y);

  float k = x + norm(objectScale,0.5,3.0)*w;

  noStroke();
  fill(255,200,0);
  ellipse(k,y,15,15);

  fill(20,30,40);
  textSize(10);
  textAlign(CENTER,CENTER);

  text("OBJECT SIZE "+nf(objectScale,0,2),
    width*0.5,y-12);
}

String[] buttonLabels() {
  return new String[] {
    "BRAKE",
    "THROTTLE",
    paused ? "RESUME" : "PAUSE",
    "NEXT OBJ",
    "ADD AXIS",
    "PREV AXIS",

    "NEXT AXIS",
    follows[selectedObserver] ? "FIX AXIS" : "FOLLOW AXIS",
    visible[selectedObserver] ? "AXIS ON" : "AXIS OFF",
    useDpad ? "D-PAD OFF" : "D-PAD ON",
    "DELETE AXIS",
    showCoordinates ? "COORDS ON" : "COORDS OFF",

    showRelative ? "REL VEL ON" : "REL VEL OFF",
    showVelocity ? "VEL ON" : "VEL OFF",
    showPosition ? "POS ON" : "POS OFF",
    showGrid ? "WORLD ON" : "WORLD OFF",
    showCells ? "VOXELS ON" : "VOXELS OFF",
    showLabels ? "LABELS ON" : "LABELS OFF",

    "CELL -",
    "CELL +",
    snapGrid ? "SNAP ON" : "SNAP OFF",
    "RESET",
    "PREV POINT",
    "NEXT POINT",

    allVoxelComponents ? "ALL VEL ON" : "ALL VEL OFF",
    allPositionVectors ? "ALL POS ON" : "ALL POS OFF",
    allVoxelAxes ? "VEL AXES ON" : "VEL AXES OFF",
    allResultants ? "RESULT ALL ON" : "RESULT ALL OFF",
    straightLine ? "STRAIGHT ON" : "STRAIGHT OFF",
    randomPath[selectedObserver] ? "RANDOM OFF" : "RANDOM PATH"
  };
}

int buttonColor(int i) {
  switch (i) {
  case 0: return color(190,50,50);
  case 1: return color(40,150,80);
  case 2: return color(60,90,140);
  case 3: return color(230,125,0);
  case 4: return color(0,135,190);
  case 5:
  case 6: return color(90,90,130);
  case 7: return color(40,125,150);
  case 8: return color(30,125,100);
  case 9: return color(175,70,30);
  case 10: return color(155,55,55);
  case 11: return color(70,100,150);
  case 12: return color(145,70,160);
  case 13: return color(190,110,20);
  case 14: return color(0,135,180);
  case 15: return color(40,100,140);
  case 16: return color(140,100,30);
  case 17: return color(80,90,110);
  case 18:
  case 19: return color(70,100,130);
  case 20: return color(130,80,120);
  case 21: return color(90,95,105);
  case 22:
  case 23: return color(170,55,55);
  case 24: return color(180,50,170);
  case 25: return color(0,95,255);
  case 26: return color(10,155,95);
  case 27: return color(0,150,145);
  case 28: return color(20,170,80);
  case 29: return color(115,45,130);
  }

  return color(65,70,80);
}

void drawControls() {
  String[] labels = buttonLabels();

  float bw = buttonWidth();
  float bh = buttonHeight();
  float gap = buttonGap();
  float m = buttonMargin();

  noStroke();
  fill(18,24,34);
  rect(0,buttonTop()-2,width,height-buttonTop()+2);

  textSize(9);
  textAlign(CENTER,CENTER);

  for (int i = 0; i < BUTTON_COUNT; i++) {
    int r = i / BUTTON_COLS;
    int c = i % BUTTON_COLS;

    float x = m + c*(bw+gap);
    float y = buttonTop() + r*36;

    fill(buttonColor(i));
    rect(x,y,bw,bh,5);

    fill(255);
    text(labels[i],x+bw*0.5,y+bh*0.5);
  }

  textAlign(LEFT,CENTER);
}


// ============================================================
// D-PAD AXIS MOVEMENT UI
// ============================================================

void drawDPad() {
  if (!useDpad || follows[selectedObserver] || randomPath[selectedObserver]) return;

  float cx = width - 120;
  float cy = buttonTop() - 110;
  float s = 45; // Button size

  // Draw background panel for D-Pad
  noStroke();
  fill(10, 22, 38, 200);
  rectMode(CENTER);
  rect(cx, cy, 170, 180, 15);
  rectMode(CORNER);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(11);
  text("MOVE AXIS " + (selectedObserver + 1), cx, cy - 75);

  // Z buttons (Depth)
  dpadBtn(cx - 50, cy - 45, s, "IN\n(-Z)", 0, 0, -1);
  dpadBtn(cx + 50, cy - 45, s, "OUT\n(+Z)", 0, 0, 1);

  // XY cross (Up/Down/Left/Right)
  dpadBtn(cx, cy - 15, s, "UP", 0, -1, 0);
  dpadBtn(cx, cy + 65, s, "DN", 0, 1, 0);
  dpadBtn(cx - 50, cy + 25, s, "LT", -1, 0, 0);
  dpadBtn(cx + 50, cy + 25, s, "RT", 1, 0, 0);
}

void dpadBtn(float x, float y, float s, String label, float dx, float dy, float dz) {
  boolean hover = dist(mouseX, mouseY, x, y) < s/2;
  boolean active = hover && mousePressed;

  fill(active ? color(255, 130, 0) : color(45, 65, 85, 230));
  stroke(active ? color(255) : color(100, 150, 200, 150));
  strokeWeight(2);
  ellipse(x, y, s, s);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(10);
  text(label, x, y - 1); // slight tweak for font centering

  // If held down, continuously move the observer
  if (active) {
    ox[selectedObserver] += dx * 3.5;
    oy[selectedObserver] += dy * 3.5;
    oz[selectedObserver] += dz * 3.5;

    // Reset manual observer velocity so it doesn't drift
    ovx[selectedObserver] = 0;
    ovy[selectedObserver] = 0;
    ovz[selectedObserver] = 0;
  }
}


// ============================================================
// TOUCH AND MOUSE INPUT
// ============================================================

void mousePressed() {
  float sx = sliderX();
  float sy = sliderY();
  float sw = sliderWidth();

  float knob = sx + norm(objectScale,0.5,3.0)*sw;

  if (dist(mouseX,mouseY,knob,sy)<23
    || (mouseY>=sy-12 && mouseY<=sy+12
    && mouseX>=sx && mouseX<=sx+sw)) {

    draggingSlider = true;
    updateScaleTouch();
    return;
  }

  float bw = buttonWidth();
  float gap = buttonGap();
  float m = buttonMargin();

  int row = int((mouseY-buttonTop())/36);

  if (row>=0 && row<BUTTON_ROWS) {
    int col = int((mouseX-m)/(bw+gap));

    if (col>=0 && col<BUTTON_COLS) {
      float bx = m+col*(bw+gap);
      float by = buttonTop()+row*36;

      if (mouseX>=bx && mouseX<=bx+bw
        && mouseY>=by && mouseY<=by+buttonHeight()) {

        int id = row*BUTTON_COLS+col;

        if (id<BUTTON_COUNT) {
          handleButton(id);
        }

        return;
      }
    }
  }

  if (mouseY<=35 || mouseY>=sliderY()-10) return;

  // Intercept touches that land on the D-Pad so the camera doesn't rotate
  if (useDpad && !follows[selectedObserver] && !randomPath[selectedObserver]) {
    float cx = width - 120;
    float cy = buttonTop() - 110;
    if (mouseX > cx - 90 && mouseX < cx + 90 && mouseY > cy - 95 && mouseY < cy + 95) {
      return; // D-pad handles movement internally
    }
  }

  draggingCamera = true;
  lastX = mouseX;
  lastY = mouseY;
}

void mouseDragged() {
  if (draggingSlider) {
    updateScaleTouch();
    return;
  }

  if (draggingCamera) {
    cameraYaw += (mouseX-lastX)*0.006;

    cameraElevation = constrain(
      cameraElevation+(mouseY-lastY)*0.004,
      0.08,0.68
    );

    lastX = mouseX;
    lastY = mouseY;
  }
}

void mouseReleased() {
  draggingSlider = false;
  draggingCamera = false;
}

void updateScaleTouch() {
  objectScale = lerp(
    0.5,3.0,
    constrain((mouseX-sliderX())/max(1,sliderWidth()),0,1)
  );

  pointsDirty = true;
}


// ============================================================
// ALL 30 BUTTON ACTIONS
// ============================================================

void handleButton(int n) {
  switch (n) {

  case 0:
    throttle = max(0,throttle-0.35);
    break;

  case 1:
    throttle = min(1,throttle+0.20);
    break;

  case 2:
    paused = !paused;
    break;

  case 3:
    currentEntity = (currentEntity+1)%ENTITY_COUNT;
    resetSimulation();
    pointsDirty = true;
    break;

  case 4:
    addObserver();
    break;

  case 5:
    prevObserver();
    break;

  case 6:
    nextObserver();
    break;

  case 7:
    follows[selectedObserver] = !follows[selectedObserver];

    if (follows[selectedObserver]) {
      randomPath[selectedObserver] = false;

      ox[selectedObserver] = entityX;
      oy[selectedObserver] = entityY;
      oz[selectedObserver] = entityZ;
    }
    break;

  case 8:
    visible[selectedObserver] = !visible[selectedObserver];
    break;

  case 9: // Was previously "Place Origin", now toggles the D-pad
    if (!follows[selectedObserver] && !randomPath[selectedObserver]) {
      useDpad = !useDpad;
    }
    break;

  case 10:
    deleteObserver();
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
    showGrid = !showGrid;
    break;

  case 16:
    showCells = !showCells;
    break;

  case 17:
    showLabels = !showLabels;
    break;

  case 18:
    cellSize = max(MIN_CELL,cellSize-2);
    pointsDirty = true;
    break;

  case 19:
    cellSize = min(MAX_CELL,cellSize+2);
    pointsDirty = true;
    break;

  case 20:
    snapGrid = !snapGrid;
    break;

  case 21:
    resetSimulation();
    break;

  case 22:
    if (pointCount>0) {
      selectedPoint =
        (selectedPoint-1+pointCount)%pointCount;
    }
    break;

  case 23:
    if (pointCount>0) {
      selectedPoint = (selectedPoint+1)%pointCount;
    }
    break;

  case 24:
    allVoxelComponents = !allVoxelComponents;
    break;

  case 25:
    allPositionVectors = !allPositionVectors;
    break;

  case 26:
    allVoxelAxes = !allVoxelAxes;
    break;

  case 27:
    allResultants = !allResultants;
    break;

  case 28:
    straightLine = !straightLine;
    animationTime = 0;
    updateEntityHeight();

    if (straightLine) {
      entityVY = 0;
    }
    break;

  case 29:
    if (randomPath[selectedObserver]) {
      randomPath[selectedObserver] = false;

      ovx[selectedObserver] = 0;
      ovy[selectedObserver] = 0;
      ovz[selectedObserver] = 0;
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
  distanceM = 0;
  elapsed = 0;
  roadOffset = 0;
  animationTime = 0;

  throttle = 0.35;
  paused = false;

  initialX = width*0.20;
  entityX = initialX;
  entityZ = 0;

  entityVX = 0;
  entityVY = 0;
  entityVZ = 0;

  updateEntityHeight();

  selectedPoint = 0;
  useDpad = false;
  draggingCamera = false;

  for (int i = 0; i < observerCount; i++) {
    if (follows[i]) {
      ox[i] = entityX;
      oy[i] = entityY;
      oz[i] = entityZ;
    }

    ovx[i] = 0;
    ovy[i] = 0;
    ovz[i] = 0;
  }

  pointsDirty = true;
  rebuildDomainPoints();
}
