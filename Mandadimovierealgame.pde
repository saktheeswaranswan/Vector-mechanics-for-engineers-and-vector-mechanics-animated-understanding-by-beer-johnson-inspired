/*
  TAMIL NADU COASTAL SAILING & WHIRLPOOL SIMULATOR
  Processing Java Mode / APDE Android / P3D
  
  STRICT SEQUENTIAL DRAWING & SELECTION WORKFLOW
*/

// ============================================================
// GLOBAL SETTINGS & STATE MACHINE
// ============================================================

int appStep = 1; // 1: Idle, 2: Draw Yellow, 3: Draw Green/Finish, 4: Select Path, 5: Vortex/Sail, 6: Sailing

boolean seaActive = false;
boolean paused = true;
boolean showVectors = false;
boolean showParticles = false;

boolean inDrawMode = false;
boolean modeDrawYellow = false;
boolean modeDrawGreen = false;
boolean drawingLine = false;
boolean tornadoPlacementMode = false;

boolean cameraLocked = false;
boolean draggingView = false;
boolean autoRotate = true;

final int BOAT_IDLE = 0;
final int BOAT_SAILING = 1;
final int BOAT_CAPTURED = 2;
final int BOAT_SUNK = 3;

int boatState = BOAT_IDLE;

final int BTN_H = 40;
final int BTN_COUNT = 14; 

final float SEA_HALF_X = 520;
final float SEA_HALF_Z = 360;
final float YELLOW_SNAP_DISTANCE = 80; 
final float VORTEX_CAPTURE_RADIUS = 105;

float boatProgress = 0;
float boatSpeed = 0.055;
float simTime = 0;
float vortexStrength = 1.0;
float waveAmp = 0;
float targetWaveAmp = 14.0; 

float captureTimer = 0;
float captureAngle = 0;
float captureRadius = 120;
float sinkDepth = 0;

float cameraYaw = 0;
float cameraPitch = HALF_PI;
float targetCameraPitch = HALF_PI;
float cameraZoom = 0.70;
float lastTouchX, lastTouchY;

// Multi-object arrays
ArrayList<PVector> vortices = new ArrayList<PVector>();
PVector activeVortex = null; 

ArrayList<PVector> tempDrawPoints = new ArrayList<PVector>();
PVector[] yellowRoute = null;
ArrayList<PVector[]> greenRoutes = new ArrayList<PVector[]>();

int selectedRouteIndex = 0; // 0 = Yellow, 1+ = Greens
PVector boatWorldPosition = new PVector();
ArrayList<WindParticle> particles = new ArrayList<WindParticle>();


// ============================================================
// SETUP
// ============================================================

void setup() {
  orientation(LANDSCAPE);
  fullScreen(P3D);
  smooth(4);
  frameRate(30);
  textSize(16);

  for (int i = 0; i < 110; i++) {
    particles.add(new WindParticle());
  }
  startFree3DView();
}


// ============================================================
// MAIN DRAW LOOP
// ============================================================

void draw() {
  // Smooth Camera Transitions
  cameraPitch = lerp(cameraPitch, targetCameraPitch, 0.08);
  if (cameraLocked) {
    cameraYaw = lerp(cameraYaw, 0, 0.15);
  } else if (autoRotate && !draggingView) {
    cameraYaw += 0.003; 
  }

  // Physics and Time
  if (seaActive && !paused) {
    simTime += 0.045; 
    waveAmp = lerp(waveAmp, targetWaveAmp, 0.025);
    for (WindParticle p : particles) p.update();
    updateBoatSimulation();
  } else {
    waveAmp = lerp(waveAmp, 0, 0.06);
  }

  background(3, 24, 42);
  drawOceanBackground();

  pushMatrix();
  translate(width * 0.5, height * 0.50, 0);
  scale(cameraZoom);
  rotateY(cameraYaw);
  rotateX(cameraPitch);

  drawSeaPlane();
  if (seaActive) drawOceanWaves();

  // Draw Saved Routes
  if (yellowRoute != null) {
    drawRoute(yellowRoute, color(255, 220, 25), selectedRouteIndex == 0 ? 8 : 4, true);
    drawStartFinishMarkers();
  }

  for (int i = 0; i < greenRoutes.size(); i++) {
    boolean isSelected = (selectedRouteIndex == (i + 1));
    drawRoute(greenRoutes.get(i), color(30, 255, 90), isSelected ? 8 : 4, true);
  }

  // Draw Live Scribble Line
  if (drawingLine) drawLiveStroke();

  for (PVector v : vortices) drawWhirlpool(v);
  if (seaActive && showVectors) drawWindField();
  if (seaActive && showParticles) drawWindParticles();

  if (boatState == BOAT_SAILING || boatState == BOAT_CAPTURED) {
    drawBoat();
  }

  popMatrix();
  drawHUD();
}


// ============================================================
// CAMERA LOGIC
// ============================================================

void startFree3DView() {
  targetCameraPitch = 1.0; cameraPitch = 1.0; cameraYaw = PI / 6; 
  cameraZoom = min((width - 36.0) / (SEA_HALF_X * 2.0), (height - 190.0) / (SEA_HALF_Z * 2.0));
  cameraZoom = constrain(cameraZoom, 0.35, 1.10);
  cameraLocked = false; autoRotate = true; 
}

void forceTopView() {
  targetCameraPitch = HALF_PI; cameraPitch = HALF_PI; cameraYaw = 0; 
  cameraZoom = min((width - 36.0) / (SEA_HALF_X * 2.0), (height - 190.0) / (SEA_HALF_Z * 2.0));
  cameraZoom = constrain(cameraZoom, 0.35, 1.10);
  cameraLocked = true; autoRotate = false; 
}


// ============================================================
// DRAWING, SMOOTHING & SELECTION LOGIC
// ============================================================

PVector clampToSea(PVector p) { 
  return new PVector(constrain(p.x, -SEA_HALF_X, SEA_HALF_X), 0, constrain(p.z, -SEA_HALF_Z, SEA_HALF_Z)); 
}

PVector screenToSea(float sx, float sy) {
  float wx = (sx - width * 0.5) / cameraZoom;
  float wz = -(sy - height * 0.50) / cameraZoom;
  return clampToSea(new PVector(wx, 0, wz));
}

PVector[] makeSmooth(PVector[] pts, int steps) {
  ArrayList<PVector> result = new ArrayList<PVector>();
  if (pts == null || pts.length < 2) return new PVector[0];
  for (int i = 0; i < pts.length - 1; i++) {
    PVector p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.length - 1)];
    for (int j = 0; j < steps; j++) {
      float t = j / (float)steps, t2 = t * t, t3 = t2 * t;
      float x = 0.5f * (2 * p1.x + (-p0.x + p2.x) * t + (2*p0.x - 5*p1.x + 4*p2.x - p3.x) * t2 + (-p0.x + 3*p1.x - 3*p2.x + p3.x) * t3);
      float z = 0.5f * (2 * p1.z + (-p0.z + p2.z) * t + (2*p0.z - 5*p1.z + 4*p2.z - p3.z) * t2 + (-p0.z + 3*p1.z - 3*p2.z + p3.z) * t3);
      result.add(new PVector(x, 0, z));
    }
  }
  result.add(pts[pts.length - 1].copy());
  return result.toArray(new PVector[result.size()]);
}

PVector closestYellowPoint(PVector p) {
  if (yellowRoute == null || yellowRoute.length == 0) return p;
  PVector best = yellowRoute[0].copy();
  float bestD = Float.MAX_VALUE;
  for (int i = 0; i < yellowRoute.length - 1; i++) {
    PVector a = yellowRoute[i], b = yellowRoute[i + 1], ab = PVector.sub(b, a);
    float denom = ab.dot(ab);
    float t = constrain(denom > 0.0001 ? PVector.sub(p, a).dot(ab) / denom : 0, 0, 1);
    PVector q = PVector.lerp(a, b, t);
    float d = PVector.dist(p, q);
    if (d < bestD) { bestD = d; best = q.copy(); }
  }
  return best;
}

void startDrawing(float sx, float sy) {
  PVector p = screenToSea(sx, sy);
  tempDrawPoints.clear();
  
  if (modeDrawGreen) {
    if (yellowRoute == null || PVector.dist(p, closestYellowPoint(p)) > YELLOW_SNAP_DISTANCE) return;
    tempDrawPoints.add(closestYellowPoint(p));
  } else if (modeDrawYellow) {
    tempDrawPoints.add(p);
  }
  drawingLine = true;
}

void continueDrawing(float sx, float sy) {
  if (!drawingLine) return;
  PVector p = clampToSea(screenToSea(sx, sy));
  if (tempDrawPoints.size() == 0 || PVector.dist(p, tempDrawPoints.get(tempDrawPoints.size() - 1)) > 5) {
    tempDrawPoints.add(p);
  }
}

void finishDrawing(float sx, float sy) {
  if (!drawingLine) return;
  drawingLine = false;
  
  if (tempDrawPoints.size() < 3) return; // Ignore accidental clicks

  if (modeDrawGreen) {
    PVector p = screenToSea(sx, sy);
    tempDrawPoints.add(closestYellowPoint(p)); // Snap end to yellow
    PVector[] raw = tempDrawPoints.toArray(new PVector[0]);
    PVector[] newRoute = makeSmooth(raw, 4);
    greenRoutes.add(newRoute);
  } 
  else if (modeDrawYellow) {
    PVector[] raw = tempDrawPoints.toArray(new PVector[0]);
    yellowRoute = makeSmooth(raw, 5);
    if (appStep == 2) appStep = 3; 
  }
  tempDrawPoints.clear();
}

float distToRoute(PVector p, PVector[] route) {
  if(route == null || route.length < 2) return Float.MAX_VALUE;
  float minDist = Float.MAX_VALUE;
  for (int i = 0; i < route.length - 1; i++) {
    PVector a = route[i], b = route[i + 1], ab = PVector.sub(b, a);
    float denom = ab.dot(ab);
    float t = constrain(denom > 0.0001 ? PVector.sub(p, a).dot(ab) / denom : 0, 0, 1);
    PVector q = PVector.lerp(a, b, t);
    float d = PVector.dist(p, q);
    if (d < minDist) minDist = d;
  }
  return minDist;
}

void selectPathByClick(float sx, float sy) {
  if (appStep != 4 && appStep != 5) return; // Only allow selection in these steps
  PVector p = screenToSea(sx, sy);
  
  float minDist = Float.MAX_VALUE;
  int bestIdx = 0;

  float dY = distToRoute(p, yellowRoute);
  if (dY < minDist) { minDist = dY; bestIdx = 0; }

  for (int i = 0; i < greenRoutes.size(); i++) {
    float dG = distToRoute(p, greenRoutes.get(i));
    if (dG < minDist) { minDist = dG; bestIdx = i + 1; }
  }

  if (minDist < 60) {
    selectedRouteIndex = bestIdx;
    if (appStep == 4) appStep = 5; // Successfully chose a path
  }
}


// ============================================================
// ENVIRONMENT RENDERING
// ============================================================

void drawOceanBackground() {
  hint(DISABLE_DEPTH_TEST);
  noStroke();
  for (int i = 0; i < 12; i++) {
    fill(2, 24 + i * 3, 42 + i * 4);
    rect(0, i * height / 12.0, width, height / 12.0 + 1);
  }
  hint(ENABLE_DEPTH_TEST);
}

void drawSeaPlane() {
  pushStyle(); noStroke();
  int step = 26;
  for (int x = -600; x <= 600; x += step) {
    for (int z = -400; z <= 400; z += step) {
      float shade = 0.5 + 0.5 * sin(x * 0.025 + z * 0.02);
      if (!seaActive) fill(8 + shade * 5, 55 + shade * 12, 78 + shade * 15);
      else fill(5 + shade * 5, 48 + shade * 12, 75 + shade * 18);
      pushMatrix(); translate(x, 0, z); box(step - 1, 1.5, step - 1); popMatrix();
    }
  }
  noFill(); stroke(100, 205, 230, 180); strokeWeight(2);
  beginShape(); vertex(-SEA_HALF_X, -1, -SEA_HALF_Z); vertex( SEA_HALF_X, -1, -SEA_HALF_Z); vertex( SEA_HALF_X, -1,  SEA_HALF_Z); vertex(-SEA_HALF_X, -1,  SEA_HALF_Z); endShape(CLOSE);
  popStyle();
}

float waveHeight(float x, float z) {
  if (!seaActive) return 0;
  float w1 = sin(x * 0.020 + simTime) + cos(z * 0.022 - simTime * 1.3);
  float w2 = 0.55 * sin(x * 0.04 - simTime * 1.7 + z * 0.035);
  float chop = 0.25 * cos(x * 0.08 + simTime * 2.5 - z * 0.06);
  return waveAmp * (w1 + w2 + chop);
}

void drawOceanWaves() {
  pushStyle(); noFill(); stroke(70, 200, 235, 120); strokeWeight(1.5);
  for (int z = -350; z <= 350; z += 42) { beginShape(); for (int x = -500; x <= 500; x += 18) vertex(x, waveHeight(x, z), z); endShape(); }
  for (int x = -500; x <= 500; x += 50) { beginShape(); for (int z = -350; z <= 350; z += 18) vertex(x, waveHeight(x, z), z); endShape(); }
  popStyle();
}

void drawRoute(PVector[] route, int routeColor, float weight, boolean arrows) {
  if (route == null || route.length < 2) return;
  pushStyle(); noFill(); stroke(routeColor); strokeWeight(weight);
  beginShape();
  for (int i = 0; i < route.length; i++) {
    float y = seaActive ? waveHeight(route[i].x, route[i].z) - 5 : -4;
    vertex(route[i].x, y, route[i].z);
  }
  endShape();
  if (arrows) {
    for (int i = 12; i < route.length - 2; i += 35) {
      PVector a = route[i], b = route[min(i + 2, route.length - 1)];
      PVector mid = PVector.lerp(a, b, 0.5), d = PVector.sub(b, a);
      if (d.mag() > 0.001) { d.normalize().mult(18); drawArrow3D(mid, d, routeColor, 9); }
    }
  }
  popStyle();
}

void drawLiveStroke() {
  if (tempDrawPoints.size() < 2) return;
  pushStyle(); noFill(); 
  if (modeDrawYellow) stroke(255, 220, 25);
  else stroke(30, 255, 90);
  strokeWeight(6);
  beginShape();
  for (PVector p : tempDrawPoints) vertex(p.x, -5, p.z);
  endShape(); popStyle();
}

void drawStartFinishMarkers() {
  if (yellowRoute == null || yellowRoute.length < 2) return;
  
  // Start
  PVector st = yellowRoute[0];
  pushMatrix(); translate(st.x, -10, st.z); stroke(color(90, 255, 150)); strokeWeight(2);
  line(0, -25, 0, 0, 0, 0); noStroke(); fill(color(90, 255, 150)); sphere(6);
  fill(255); textAlign(CENTER); textSize(13); text("START", 0, -34, 0); popMatrix();
  
  // Finish
  PVector fn = yellowRoute[yellowRoute.length - 1];
  pushMatrix(); translate(fn.x, -10, fn.z); stroke(color(255, 100, 100)); strokeWeight(2);
  line(0, -25, 0, 0, 0, 0); noStroke(); fill(color(255, 100, 100)); sphere(6);
  fill(255); textAlign(CENTER); textSize(13); text("FINISH", 0, -34, 0); popMatrix();
}

void drawWhirlpool(PVector v) {
  pushMatrix();
  float yOffset = seaActive ? (waveHeight(v.x, v.z) * 0.3) - 2 : -2;
  translate(v.x, yOffset, v.z);
  noStroke();
  for (int ring = 18; ring >= 1; ring--) {
    float r = ring * 9.5, ratio = 1.0 - ring / 18.0;
    float y = 5 + ratio * ratio * 220 + sin(simTime * 2 + ring * 0.4) * 2;
    fill(2, 16, 28, 15 + ring * 2);
    pushMatrix(); translate(0, y, 0); scale(1, 0.10, 1); ellipse(0, 0, r * 2, r * 2); popMatrix();
  }
  noFill();
  for (int ring = 0; ring < 10; ring++) {
    stroke(55, 190, 235, max(25, 150 - ring * 12)); strokeWeight(2.3);
    beginShape();
    for (int a = 0; a <= 360; a += 5) {
      float ang = radians(a) + simTime * (0.55 + ring * 0.035);
      float r = 28 + ring * 10 + 4 * sin(ang * 3 + simTime);
      float ratio = 1.0 - constrain(r / 155.0, 0, 1);
      float y = -3 + ratio * ratio * 220 + sin(ang * 2 + simTime) * 2;
      vertex(cos(ang) * r, y, sin(ang) * r);
    }
    endShape();
  }
  noStroke(); fill(0, 5, 12);
  pushMatrix(); translate(0, 225, 0); scale(1, 0.08, 1); ellipse(0, 0, 45, 45); popMatrix();
  popMatrix();
}


// ============================================================
// SAILING SEQUENCE
// ============================================================

PVector[] getActiveBoatRoute() {
  if (selectedRouteIndex == 0) return yellowRoute;
  int gIdx = selectedRouteIndex - 1;
  if (gIdx >= 0 && gIdx < greenRoutes.size()) return greenRoutes.get(gIdx);
  return yellowRoute; 
}

PVector pointOnRoute(PVector[] route, float t) {
  if (route == null || route.length == 0) return new PVector();
  if (route.length == 1) return route[0].copy();
  float total = 0;
  for (int i = 0; i < route.length - 1; i++) total += PVector.dist(route[i], route[i + 1]);
  if (total <= 0.001) return route[0].copy();
  float target = constrain(t, 0, 1) * total;
  for (int i = 0; i < route.length - 1; i++) {
    float d = PVector.dist(route[i], route[i + 1]);
    if (target <= d) return PVector.lerp(route[i], route[i + 1], d <= 0.001 ? 0 : target / d);
    target -= d;
  }
  return route[route.length - 1].copy();
}

void startSailingSequence() {
  if (yellowRoute == null) return;
  seaActive = true; paused = false; targetWaveAmp = 14.0; showParticles = true;
  boatProgress = 0; captureTimer = 0; captureAngle = 0; captureRadius = 145; sinkDepth = 0;
  
  boatWorldPosition = pointOnRoute(getActiveBoatRoute(), 0);
  boatState = BOAT_SAILING; 
  appStep = 6; 
}

void updateBoatSimulation() {
  if (boatState == BOAT_SAILING) {
    PVector[] route = getActiveBoatRoute();
    if (route == null || route.length < 2) return;
    boatProgress = min(boatProgress + boatSpeed * 0.006, 1.0);
    boatWorldPosition = pointOnRoute(route, boatProgress);

    float minDist = Float.MAX_VALUE; PVector closestV = null;
    for (PVector v : vortices) {
      float d = dist(boatWorldPosition.x, boatWorldPosition.z, v.x, v.z);
      if (d < minDist) { minDist = d; closestV = v; }
    }

    if (minDist <= VORTEX_CAPTURE_RADIUS || boatProgress >= 1.0) {
      if (minDist > VORTEX_CAPTURE_RADIUS && closestV != null) {
        PVector offset = PVector.sub(boatWorldPosition, closestV);
        if (offset.mag() < 0.001) offset.set(1, 0, 0);
        offset.normalize().mult(145);
        boatWorldPosition.set(closestV.x + offset.x, 0, closestV.z + offset.z);
        minDist = 145;
      }
      activeVortex = closestV; boatState = BOAT_CAPTURED; captureTimer = 0;
      if(activeVortex != null) {
        captureAngle = atan2(boatWorldPosition.z - activeVortex.z, boatWorldPosition.x - activeVortex.x);
        captureRadius = max(24, minDist);
      }
    }
  } else if (boatState == BOAT_CAPTURED && activeVortex != null) {
    captureTimer += 1.0 / 30.0; captureAngle += 0.095 + vortexStrength * 0.035;
    captureRadius = max(7, captureRadius - 0.55); sinkDepth = min(180, sinkDepth + 0.75);
    boatWorldPosition.set(activeVortex.x + cos(captureAngle) * captureRadius, 0, activeVortex.z + sin(captureAngle) * captureRadius);
    if (captureTimer > 6.0) boatState = BOAT_SUNK;
  }
}

void drawBoat() {
  PVector pos, dir;
  if (boatState == BOAT_CAPTURED) {
    pos = boatWorldPosition.copy(); dir = new PVector(-sin(captureAngle), 0, cos(captureAngle));
  } else {
    PVector[] route = getActiveBoatRoute();
    pos = pointOnRoute(route, boatProgress);
    PVector a = pointOnRoute(route, max(0, boatProgress - 0.004)), b = pointOnRoute(route, min(1, boatProgress + 0.004));
    dir = PVector.sub(b, a).normalize();
  }
  pushMatrix();
  translate(pos.x, waveHeight(pos.x, pos.z) - 12 - sinkDepth, pos.z);
  rotateY(atan2(dir.x, dir.z));
  if (seaActive && boatState != BOAT_CAPTURED) rotateX(0.25 * sin(simTime * 3.0 + pos.x * 0.05));
  pushStyle(); noStroke(); fill(95, 55, 25);
  beginShape(); vertex(-13, 0, -26); vertex(13, 0, -26); vertex(9, 3, 20); vertex(0, 6, 30); vertex(-9, 3, 20); endShape(CLOSE);
  fill(235, 225, 195); beginShape(TRIANGLES); vertex(0, -42, -5); vertex(0, -4, -5); vertex(24, -4, 12); endShape();
  fill(245, 235, 210); beginShape(TRIANGLES); vertex(0, -35, -3); vertex(0, -4, -3); vertex(-20, -4, 12); endShape();
  stroke(50, 35, 20); strokeWeight(2); line(0, -44, 0, 0, 0, 0); popStyle();
  popMatrix();
}


// ============================================================
// HUD & WORKFLOW INSTRUCTIONS
// ============================================================

String getInstructionMessage() {
  switch(appStep) {
    case 1: return "படி 1: Click 'DRAW MODE' to begin designing paths.";
    case 2: return "படி 2: Click 'YELLOW' and drag to draw the MAIN path.";
    case 3: return "படி 3: Click 'GREEN' to add branches, or 'FINISH DRAW'.";
    case 4: return "படி 4: Tap on the Yellow or Green line on the sea to CHOOSE PATH.";
    case 5: return "படி 5: Click 'PLACE VORTEX' or click 'SAIL!' to start the journey.";
    case 6: return boatState == BOAT_SUNK ? "படகு மூழ்கியது! RESET அழுத்தி மீண்டும் தொடங்கவும்." : "படகு பயணம் செய்கிறது! (SAILING)";
  }
  return "";
}

String buttonLabel(int i) {
  String[] labels = { "DRAW MODE", "YELLOW", "GREEN", "FINISH DRAW", "PLACE VORTEX", "SAIL!", "RESET", 
                      "3D VIEW", "TOP VIEW", "WAVES", "VECTORS", "SPEED +", "PAUSE", "CLEAR PATHS" };
  if(i == 1 && modeDrawYellow) return "[ DRAWING YELLOW ]";
  if(i == 2 && modeDrawGreen) return "[ DRAWING GREEN ]";
  return labels[i];
}

void drawHUD() {
  hint(DISABLE_DEPTH_TEST);
  camera(); noLights(); noStroke();
  
  fill(0, 0, 0, 220); rect(0, 0, width, 85);
  fill(255, 240, 170); textAlign(CENTER, CENTER); textSize(24);
  text("தமிழ்நாடு கடல் பயணம் — SEQUENTIAL WORKFLOW", width / 2, 25);

  fill(255, 255, 100); textSize(18);
  text(getInstructionMessage(), width / 2, 60);

  drawButtons();
  hint(ENABLE_DEPTH_TEST);
}

void drawButtons() {
  int margin = 7, gap = 5, cols = 7, rows = 2, bw = (width - margin * 2 - gap * (cols - 1)) / cols, bh = BTN_H;
  int y0 = height - (bh * rows + gap * (rows - 1)) - 8;

  for (int i = 0; i < BTN_COUNT; i++) {
    int x = margin + (i % cols) * (bw + gap), y = y0 + (i / cols) * (bh + gap);
    
    boolean isActive = (i == 0 && inDrawMode) || (i == 1 && modeDrawYellow) || (i == 2 && modeDrawGreen) || 
                       (i == 4 && tornadoPlacementMode) || (i == 5 && boatState == BOAT_SAILING) || 
                       (i == 7 && !cameraLocked) || (i == 8 && cameraLocked) || (i == 9 && seaActive);
                       
    // Highlight step
    boolean isNextStep = false;
    if (appStep == 1 && i == 0) isNextStep = true;
    if (appStep == 2 && i == 1) isNextStep = true;
    if (appStep == 3 && (i == 2 || i == 3)) isNextStep = true;
    if (appStep == 5 && (i == 4 || i == 5)) isNextStep = true;

    fill(isActive ? color(16, 125, 92, 240) : color(8, 31, 49, 235));
    
    if (isNextStep) {
      strokeWeight(3); stroke(255, 255, 0); 
    } else {
      strokeWeight(1.2); stroke(isActive ? color(110, 255, 190) : color(100, 180, 205));
    }
    
    rect(x, y, bw, bh, 8);
    fill(isNextStep ? color(255, 255, 150) : color(255)); 
    noStroke(); textAlign(CENTER, CENTER); textSize(min(13, bw * 0.16));
    text(buttonLabel(i), x + bw / 2, y + bh / 2);
  }
}

int buttonAt(float x, float y) {
  int margin = 7, gap = 5, cols = 7, rows = 2, bw = (width - margin * 2 - gap * (cols - 1)) / cols, bh = BTN_H;
  int y0 = height - (bh * rows + gap * (rows - 1)) - 8;
  for (int i = 0; i < BTN_COUNT; i++) {
    int bx = margin + (i % cols) * (bw + gap), by = y0 + (i / cols) * (bh + gap);
    if (x >= bx && x <= bx + bw && y >= by && y <= by + bh) return i;
  }
  return -1;
}


// ============================================================
// BUTTON ACTIONS & INPUT
// ============================================================

void activateButton(int idx) {
  if (idx == 0) { // DRAW MODE
    forceTopView();
    inDrawMode = true; modeDrawYellow = false; modeDrawGreen = false; tornadoPlacementMode = false;
    if(appStep == 1) appStep = 2;
  } else if (idx == 1 && inDrawMode) { // YELLOW
    modeDrawYellow = true; modeDrawGreen = false; tornadoPlacementMode = false;
  } else if (idx == 2 && inDrawMode && yellowRoute != null) { // GREEN
    modeDrawGreen = true; modeDrawYellow = false; tornadoPlacementMode = false;
  } else if (idx == 3 && inDrawMode) { // FINISH DRAW
    inDrawMode = false; modeDrawYellow = false; modeDrawGreen = false;
    if (yellowRoute != null) appStep = 4;
  } else if (idx == 4) { // PLACE VORTEX
    tornadoPlacementMode = true; inDrawMode = false; modeDrawYellow = false; modeDrawGreen = false;
    forceTopView();
  } else if (idx == 5) { // SAIL!
    inDrawMode = false; modeDrawYellow = false; modeDrawGreen = false; tornadoPlacementMode = false;
    startSailingSequence();
  } else if (idx == 6) { // RESET
    appStep = 1; seaActive = false; inDrawMode = false; modeDrawYellow = false; modeDrawGreen = false; 
    tornadoPlacementMode = false; yellowRoute = null; greenRoutes.clear(); vortices.clear();
    boatState = BOAT_IDLE; boatProgress = 0; simTime = 0; waveAmp = 0; selectedRouteIndex = 0;
    startFree3DView();
  } else if (idx == 7) { 
    startFree3DView();
  } else if (idx == 8) { 
    forceTopView();
  } else if (idx == 9) { 
    seaActive = !seaActive; if (seaActive) { paused = false; targetWaveAmp = 14.0; showParticles = true; } else waveAmp = 0;
  } else if (idx == 10) { 
    showVectors = !showVectors; 
  } else if (idx == 11) { 
    boatSpeed = boatSpeed > 0.18 ? 0.03 : boatSpeed + 0.025;
  } else if (idx == 12) { 
    paused = !paused;
  } else if (idx == 13) { 
    yellowRoute = null; greenRoutes.clear(); selectedRouteIndex = 0; if (appStep > 1 && appStep < 6) appStep = 2;
  }
}

void handlePointerDown(float sx, float sy) {
  int idx = buttonAt(sx, sy);
  if (idx >= 0) { activateButton(idx); draggingView = false; return; }

  // App step handlers
  if (appStep == 4 || appStep == 5) { selectPathByClick(sx, sy); }
  if (tornadoPlacementMode) { vortices.add(new PVector(screenToSea(sx, sy).x, 0, screenToSea(sx, sy).z)); return; }
  if (inDrawMode && (modeDrawYellow || modeDrawGreen)) { startDrawing(sx, sy); return; }
  
  if (cameraLocked) return;

  lastTouchX = sx; lastTouchY = sy;
  draggingView = true; autoRotate = false;
}

void handlePointerMove(float sx, float sy) {
  if (drawingLine) { continueDrawing(sx, sy); return; }
  if (!draggingView || cameraLocked) return;
  cameraYaw += (sx - lastTouchX) * 0.008;
  targetCameraPitch = constrain(targetCameraPitch + (sy - lastTouchY) * 0.008, 0.05, HALF_PI);
  lastTouchX = sx; lastTouchY = sy;
}

void handlePointerUp(float sx, float sy) {
  if (drawingLine) finishDrawing(sx, sy);
  draggingView = false;
}

void mousePressed() { handlePointerDown(mouseX, mouseY); }
void mouseDragged() { handlePointerMove(mouseX, mouseY); }
void mouseReleased() { handlePointerUp(mouseX, mouseY); }
void touchStarted() { if (touches.length == 1) handlePointerDown(touches[0].x, touches[0].y); }
void touchMoved() { if (touches.length == 1) handlePointerMove(touches[0].x, touches[0].y); }
void touchEnded() { if (touches.length == 1) handlePointerUp(touches[0].x, touches[0].y); draggingView = false; }


// ============================================================
// WIND FIELD
// ============================================================

void drawArrow3D(PVector origin, PVector direction, int c, float headSize) {
  if (direction.mag() < 0.001) return;
  PVector d = direction.copy().normalize(); PVector end = PVector.add(origin, direction);
  stroke(c); strokeWeight(2); line(origin.x, origin.y, origin.z, end.x, end.y, end.z);
  PVector side = new PVector(-d.z, 0, d.x); if (side.mag() < 0.01) side.set(1, 0, 0); side.normalize().mult(headSize * 0.45);
  PVector back = PVector.sub(end, PVector.mult(d, headSize));
  line(end.x, end.y, end.z, back.x + side.x, back.y, back.z + side.z);
  line(end.x, end.y, end.z, back.x - side.x, back.y, back.z - side.z);
}

void drawWindField() {
  if (!showVectors || !seaActive) return;
  pushStyle();
  for (int x = -500; x <= 500; x += 100) {
    for (int z = -300; z <= 300; z += 100) {
      PVector p = new PVector(x, waveHeight(x,z) - 24, z);
      PVector v = new PVector(0.8, 0, -0.35);
      v.x += 0.22 * sin(p.z * 0.018 + simTime); v.z += 0.18 * cos(p.x * 0.015 - simTime * 0.7);
      for (PVector vortex : vortices) {
        float dx = p.x - vortex.x, dz = p.z - vortex.z, r2 = max(700, dx * dx + dz * dz), influence = vortexStrength * 11000.0 / r2;
        v.x += -dz * influence * 0.012 - dx * 0.0009 * influence; v.z += dx * influence * 0.012 - dz * 0.0009 * influence;
      }
      drawArrow3D(p, v.mult(0.6), color(120, 220, 255, 170), 10);
    }
  }
  popStyle();
}

void drawWindParticles() {
  if (!showParticles || !seaActive) return;
  pushStyle(); strokeWeight(2.5);
  for (WindParticle p : particles) { stroke(p.c, 180); point(p.pos.x, p.pos.y + waveHeight(p.pos.x, p.pos.z)*0.5, p.pos.z); }
  popStyle();
}

class WindParticle {
  PVector pos; int c;
  WindParticle() { reset(); }
  void reset() { pos = new PVector(random(-520, 520), random(-42, -10), random(-320, 320)); c = color(random(80, 150), random(190, 240), 255); }
  void update() {
    if (!seaActive || paused) return;
    PVector v = new PVector(0.8, 0, -0.35); 
    v.x += 0.22 * sin(pos.z * 0.018 + simTime); v.z += 0.18 * cos(pos.x * 0.015 - simTime * 0.7);
    for (PVector vortex : vortices) {
        float dx = pos.x - vortex.x, dz = pos.z - vortex.z, r2 = max(700, dx * dx + dz * dz), influence = vortexStrength * 11000.0 / r2;
        v.x += -dz * influence * 0.012 - dx * 0.0009 * influence; v.z += dx * influence * 0.012 - dz * 0.0009 * influence;
    }
    pos.add(v.mult(1.5));
    if (pos.x < -560 || pos.x > 560 || pos.z < -360 || pos.z > 360) reset();
  }
}
