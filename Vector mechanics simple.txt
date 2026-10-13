vector mechanics for engineers


/*
  MULTI-ENTITY VELOCITY & POSITION VECTOR VISUALIZER
  Processing Android Mode / Java Mode
  No external libraries required.
*/

float speedKmh = 0;
float targetSpeed = 0;
float throttle = 0.35;
float worldDistance = 0;
float elapsedTime = 0;

boolean paused = false;
boolean showVectors = true;
boolean showPositionVectors = false; 
boolean showHeadlightVector = false; 

float roadY, roadHeight, entityX, entityY, scooterScale = 2.0;
boolean draggingSlider = false;

int backgroundSky = color(153, 213, 247);
int roadColor = color(63, 66, 73);
PFont uiFont;

// Entity System
int currentScreen = 0;
String[] entityNames = {"MAN", "SCOOTER", "BICYCLE", "BULLOCK CART", "LORRY", "CAR", "AEROPLANE", "BIRD", "SNAIL", "TORTOISE", "LEOPARD", "ELEPHANT"};
float[] maxSpeeds =    {15,    90,        30,        15,             120,     180,   900,         60,     1,       3,          110,       40}; // km/h

// Dynamic head/focal points for the red vector for each entity (x, y relative to entity center)
float hx, hy; 

void settings() { fullScreen(); }

void setup() {
  orientation(LANDSCAPE);
  frameRate(60);
  smooth(4);
  uiFont = createFont("sans-serif", 18, true);
  textFont(uiFont);
}

void draw() {
  updateSimulation();
  drawBackground();
  drawRoad();
  drawDistanceMarkers();
  drawEntityBase();
  drawHUD();
  drawScaleSlider();
  drawControls();
}

void updateSimulation() {
  float dt = min(0.05, 1.0 / max(frameRate, 1));
  if (!paused) {
    targetSpeed = throttle * maxSpeeds[currentScreen];
    speedKmh = lerp(speedKmh, targetSpeed, 0.8 * dt);
    worldDistance += (speedKmh / 3.6) * dt;
    elapsedTime += dt;
  }
}

void drawBackground() {
  background(currentScreen == 6 || currentScreen == 7 ? color(100, 180, 255) : backgroundSky); // Higher sky for plane/bird
  noStroke(); fill(255, 226, 128); ellipse(width * 0.83, height * 0.14, width * 0.09, width * 0.09);
  fill(108, 174, 125);
  beginShape(); vertex(0, height * 0.40); vertex(width * 0.25, height * 0.39); vertex(width * 0.55, height * 0.40); vertex(width, height * 0.40); vertex(width, height); vertex(0, height); endShape(CLOSE);
}

void drawRoad() {
  roadY = height * 0.65; roadHeight = height * 0.35;
  noStroke(); fill(roadColor); rect(0, roadY, width, roadHeight);
  fill(250, 245, 205);
  float dashW = width * 0.045, cycle = dashW * 1.75;
  float offset = (worldDistance * 16) % cycle;
  for (float x = -cycle - offset; x < width + cycle; x += cycle) rect(x, roadY + roadHeight * 0.56, dashW, height * 0.008);
}

void drawDistanceMarkers() {
  float spacing = width * 0.10, offset = (worldDistance * 16) % spacing;
  for (float x = -spacing - offset; x < width + spacing; x += spacing) {
    stroke(220); strokeWeight(2); line(x, roadY + roadHeight * 0.31, x, roadY + roadHeight * 0.335); noStroke();
  }
}

void drawEntityBase() {
  float s = max(0.55, min(width / 1000.0, height / 500.0)) * scooterScale;
  entityX = width * 0.43;
  
  // Elevate flying objects
  float altitude = (currentScreen == 6 || currentScreen == 7) ? roadHeight * 1.2 : 22 * s;
  entityY = (roadY + roadHeight * 0.65) - altitude; 

  pushMatrix();
  translate(entityX, entityY);
  
  // Draw the specific entity shape
  drawActiveEntityShape(s);

  // Draw Vectors
  if (!showHeadlightVector) {
    drawSubdividedVelocityVectors(s);
  } else {
    drawRedHeadVector(s);
  }
  popMatrix();
}

void drawActiveEntityShape(float s) {
  noStroke();
  switch(currentScreen) {
    case 0: // MAN
      fill(220, 180, 150); ellipse(0, -60*s, 30*s, 30*s); // Head
      fill(40, 100, 180); rect(-15*s, -45*s, 30*s, 50*s, 5*s); // Body
      fill(50); rect(-12*s, 5*s, 10*s, 40*s); rect(2*s, 5*s, 10*s, 40*s); // Legs
      hx = 15*s; hy = -65*s; break;
    case 1: // SCOOTER (Simplified)
      fill(30); ellipse(-40*s, 0, 35*s, 35*s); ellipse(40*s, 0, 35*s, 35*s); // Wheels
      fill(190, 40, 40); rect(-50*s, -35*s, 100*s, 25*s, 10*s); // Body
      fill(200); rect(20*s, -65*s, 5*s, 40*s); // Stem
      fill(255, 240, 150); ellipse(35*s, -30*s, 10*s, 15*s); // Headlight
      hx = 40*s; hy = -30*s; break;
    case 2: // BICYCLE
      stroke(200); strokeWeight(4*s); noFill(); ellipse(-40*s, 0, 40*s, 40*s); ellipse(40*s, 0, 40*s, 40*s);
      line(-40*s, 0, 0, -30*s); line(0, -30*s, 40*s, 0); line(40*s, 0, 20*s, -45*s); line(20*s, -45*s, -20*s, -45*s); line(-20*s, -45*s, -40*s, 0);
      noStroke(); fill(220, 180, 150); ellipse(10*s, -80*s, 25*s, 25*s); fill(40, 150, 80); rect(-10*s, -65*s, 20*s, 40*s, 5*s);
      hx = 25*s; hy = -80*s; break;
    case 3: // BULLOCK CART
      fill(100, 70, 40); ellipse(-30*s, 0, 60*s, 60*s); rect(-60*s, -30*s, 80*s, 20*s); // Cart
      stroke(100, 70, 40); strokeWeight(5*s); line(20*s, -20*s, 70*s, -20*s); noStroke();
      fill(200); rect(50*s, -40*s, 40*s, 50*s, 10*s); ellipse(90*s, -30*s, 20*s, 20*s); // Bullock
      hx = 100*s; hy = -30*s; break;
    case 4: // LORRY
      fill(50); ellipse(-80*s, 10*s, 30*s, 30*s); ellipse(-30*s, 10*s, 30*s, 30*s); ellipse(70*s, 10*s, 30*s, 30*s);
      fill(150, 50, 50); rect(-100*s, -70*s, 140*s, 70*s); // Trailer
      fill(40, 80, 150); rect(40*s, -50*s, 50*s, 50*s, 10*s); // Cab
      fill(200, 230, 255); rect(65*s, -40*s, 25*s, 20*s); // Window
      hx = 90*s; hy = -20*s; break;
    case 5: // CAR
      fill(30); ellipse(-50*s, 15*s, 25*s, 25*s); ellipse(50*s, 15*s, 25*s, 25*s);
      fill(50, 150, 200); rect(-70*s, -20*s, 140*s, 30*s, 10*s);
      fill(50, 150, 200); rect(-40*s, -45*s, 80*s, 30*s, 20*s, 20*s, 0, 0);
      hx = 70*s; hy = -10*s; break;
    case 6: // AEROPLANE
      fill(220); ellipse(0, 0, 160*s, 40*s); // Fuselage
      fill(180); triangle(-20*s, -20*s, 20*s, -20*s, -40*s, -70*s); // Tail
      fill(150); triangle(20*s, 10*s, -20*s, 10*s, 0, 60*s); // Wing
      hx = 80*s; hy = 0; break;
    case 7: // BIRD
      fill(80); ellipse(0, 0, 60*s, 25*s); // Body
      fill(100); triangle(-10*s, 0, 10*s, 0, 0, -40*s); // Wing Up
      fill(200, 150, 50); triangle(30*s, -5*s, 30*s, 5*s, 45*s, 0); // Beak
      hx = 45*s; hy = 0; break;
    case 8: // SNAIL
      fill(150, 200, 100); rect(-20*s, 10*s, 50*s, 10*s, 5*s); // Body
      line(30*s, 10*s, 40*s, -10*s); // Antenna
      fill(200, 150, 100); ellipse(-10*s, -5*s, 40*s, 40*s); // Shell
      hx = 40*s; hy = -10*s; break;
    case 9: // TORTOISE
      fill(50, 120, 60); ellipse(-25*s, 15*s, 15*s, 15*s); ellipse(25*s, 15*s, 15*s, 15*s); // Legs
      ellipse(40*s, 5*s, 20*s, 15*s); // Head
      fill(100, 150, 80); arc(0, 15*s, 70*s, 50*s, PI, TWO_PI); // Shell
      hx = 50*s; hy = 5*s; break;
    case 10: // LEOPARD
      fill(220, 170, 50); rect(-40*s, -20*s, 80*s, 25*s, 10*s); // Body
      rect(-35*s, 0, 10*s, 30*s); rect(25*s, 0, 10*s, 30*s); // Legs
      ellipse(50*s, -25*s, 25*s, 25*s); // Head
      fill(30); ellipse(-10*s, -10*s, 5*s, 5*s); ellipse(10*s, -5*s, 5*s, 5*s); ellipse(-25*s, -5*s, 5*s, 5*s); // Spots
      hx = 60*s; hy = -25*s; break;
    case 11: // ELEPHANT
      fill(120); rect(-50*s, -60*s, 100*s, 80*s, 20*s); // Body
      rect(-45*s, 20*s, 20*s, 30*s); rect(25*s, 20*s, 20*s, 30*s); // Legs
      ellipse(60*s, -40*s, 50*s, 50*s); // Head
      rect(75*s, -30*s, 15*s, 60*s, 5*s); // Trunk
      hx = 90*s; hy = -10*s; break;
  }
}

boolean isInsideEntity(float x, float y) {
  // Simplified generic bounding box/radius check for the vector squares based on current screen
  switch(currentScreen) {
    case 0: return (x > -20 && x < 20 && y > -80 && y < 50); // Man
    case 1: return (x > -60 && x < 50 && y > -70 && y < 20); // Scooter
    case 2: return (x > -50 && x < 50 && y > -90 && y < 20); // Bicycle
    case 3: return (x > -70 && x < 100 && y > -50 && y < 40); // Cart
    case 4: return (x > -110 && x < 100 && y > -80 && y < 30); // Lorry
    case 5: return (x > -80 && x < 80 && y > -50 && y < 30); // Car
    case 6: return (x > -80 && x < 80 && y > -50 && y < 50); // Plane
    case 7: return (x > -40 && x < 50 && y > -40 && y < 30); // Bird
    case 8: return (x > -40 && x < 50 && y > -30 && y < 30); // Snail
    case 9: return (x > -40 && x < 60 && y > -20 && y < 30); // Tortoise
    case 10: return (x > -50 && x < 70 && y > -40 && y < 40); // Leopard
    case 11: return (x > -60 && x < 100 && y > -70 && y < 60); // Elephant
  }
  return false;
}

void drawRedHeadVector(float s) {
  float PPM = 16.0; 
  float globalOx = (width * 0.1) - (worldDistance * PPM) - entityX;
  float globalOy = (roadY + roadHeight * 0.85) - entityY;

  if (frameCount % 40 < 20) { 
    stroke(255, 0, 0, 180); strokeWeight(max(2, 2.5 * s));
    line(globalOx, globalOy, hx, hy);
    fill(255, 100, 100); textSize(max(12, 14 * s));
    text(nf(dist(globalOx, globalOy, hx, hy) / PPM, 0, 1) + "m", lerp(globalOx, hx, 0.5), lerp(globalOy, hy, 0.5) - 10);
  }
  
  if (speedKmh >= 0.5) {
    float arrowLength = map(speedKmh, 0, maxSpeeds[currentScreen], 0, 120 * s); 
    stroke(250, 50, 50); strokeWeight(max(4, 6 * s));
    line(hx, hy, hx + arrowLength, hy);
    line(hx + arrowLength, hy, hx + arrowLength - 12*s, hy - 7*s);
    line(hx + arrowLength, hy, hx + arrowLength - 12*s, hy + 7*s);
  }
}

void drawSubdividedVelocityVectors(float s) {
  float step = 20 * s, PPM = 16.0; 
  float globalOx = (width * 0.1) - (worldDistance * PPM) - entityX;
  float globalOy = (roadY + roadHeight * 0.85) - entityY;
  float arrowLength = map(speedKmh, 0, maxSpeeds[currentScreen], 0, 65 * s);

  for (float gx = -150 * s; gx < 150 * s; gx += step) {
    for (float gy = -150 * s; gy < 100 * s; gy += step) {
      float cx = gx + step / 2.0, cy = gy + step / 2.0;
      if (isInsideEntity(cx / s, cy / s)) {
        if (showVectors || showPositionVectors) {
          stroke(255, 170, 0, 80); strokeWeight(1.5 * s); noFill(); rect(gx, gy, step, step);
          noStroke(); fill(255, 200, 0); ellipse(cx, cy, 4 * s, 4 * s);
        }
        if (showPositionVectors) {
          stroke(0, 200, 255, 140); strokeWeight(2 * s); line(globalOx, globalOy, cx, cy);
        }
        if (showVectors && speedKmh >= 0.5) {
          stroke(255, 170, 0); strokeWeight(3 * s); line(cx, cy, cx + arrowLength, cy);
        }
      }
    }
  }
}

void drawHUD() {
  fill(12, 23, 38, 220); rect(width - 320, 20, 300, 180, 16);
  fill(255); textSize(20); text(entityNames[currentScreen] + " TELEMETRY", width - 300, 50);
  textSize(16); fill(180, 230, 255);
  text("Speed: " + nf(speedKmh, 0, 1) + " km/h (Max: " + maxSpeeds[currentScreen] + ")", width - 300, 90);
  text("Distance: " + nf(worldDistance, 0, 1) + " m", width - 300, 120);
  text("Time: " + nf(elapsedTime, 0, 1) + " s", width - 300, 150);
}

void drawScaleSlider() {
  float sliderW = 300, sliderX = width / 2 - sliderW / 2, sliderY = height - 120;
  stroke(150); strokeWeight(6); line(sliderX, sliderY, sliderX + sliderW, sliderY);
  noStroke(); fill(draggingSlider ? color(255, 230, 80) : color(255, 200, 0));
  ellipse(sliderX + norm(scooterScale, 0.5, 4.0) * sliderW, sliderY, 24, 24);
  fill(255); textAlign(CENTER, CENTER); text("Adjust Size", width / 2, sliderY - 22); textAlign(LEFT, CENTER);
}

void drawControls() {
  float bW = 120, gap = 10, startX = (width - (bW*8 + gap*7)) / 2, y = height - 70;
  String[] labels = {"BRAKE", "THROTTLE", paused?"RESUME":"PAUSE", showVectors?"HIDE VEL":"VELOCITY", showPositionVectors?"HIDE POS":"POS VECS", "RESET", showHeadlightVector?"HIDE HEAD":"HEAD VEC", "NEXT >>"};
  int[] colors = {color(190,50,50), color(40,150,80), color(60,90,140), color(100,70,140), color(0,150,200), color(90,95,105), color(200,50,50), color(255,150,0)};
  
  for(int i=0; i<8; i++) {
    fill(colors[i]); rect(startX + i*(bW+gap), y, bW, 45, 10);
    fill(255); textAlign(CENTER, CENTER); text(labels[i], startX + i*(bW+gap) + bW/2, y + 22); textAlign(LEFT, CENTER);
  }
}

void mousePressed() {
  float sliderW = 300, sliderX = width / 2 - sliderW / 2, sliderY = height - 120;
  if (dist(mouseX, mouseY, sliderX + norm(scooterScale, 0.5, 4.0) * sliderW, sliderY) < 25) { draggingSlider = true; return; }

  float bW = 120, gap = 10, startX = (width - (bW*8 + gap*7)) / 2, y = height - 70;
  if (mouseY > y && mouseY < y + 45) {
    int idx = int((mouseX - startX) / (bW + gap));
    if (idx == 0) throttle = max(0, throttle - 0.35);
    if (idx == 1) throttle = min(1, throttle + 0.20);
    if (idx == 2) paused = !paused;
    if (idx == 3) { showVectors = !showVectors; showHeadlightVector = false; }
    if (idx == 4) { showPositionVectors = !showPositionVectors; showHeadlightVector = false; }
    if (idx == 5) resetSimulation();
    if (idx == 6) { showHeadlightVector = !showHeadlightVector; showVectors = false; showPositionVectors = false; }
    if (idx == 7) { currentScreen = (currentScreen + 1) % 12; resetSimulation(); } // NEXT BUTTON LOGIC
  }
}
void mouseDragged() { if (draggingSlider) scooterScale = lerp(0.5, 4.0, constrain((mouseX - (width/2 - 150)) / 300.0, 0, 1)); }
void mouseReleased() { draggingSlider = false; }
void resetSimulation() { speedKmh = targetSpeed = worldDistance = elapsedTime = throttle = 0; paused = false; scooterScale = 2.0; }
