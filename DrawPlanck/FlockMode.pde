import java.util.Collections;

public class FlockMode extends Mode {

  private Flock flock;

  private WallManager wallManager;

  private int newXOffset;
  private int newYOffset;
  private int currentX;
  private int currentY;
  private ArrayList<Integer> asyncPressCounter;

  private long lastScoringTime;
  private long lastDeathTime;
  private int iframes;
  private int score;
  private int highScore;
  private int lives;
  private boolean alive;
  private PFont font;

  public FlockMode() {
    this.modeName = "Nuée rétro - Retro Flock";

    //set defaults used by loadConfigFrom
    this.defaultConfig.setProperty("MAX_FLOCK_SIZE", "10");
    this.defaultConfig.setProperty("TOP_RIGHT_NOTE", "UP");
    this.defaultConfig.setProperty("TOP_LEFT_NOTE", "DOWN");
    this.defaultConfig.setProperty("BOTTOM_LEFT_NOTE", "LEFT");
    this.defaultConfig.setProperty("BOTTOM_RIGHT_NOTE", "RIGHT");
    this.defaultConfig.setProperty("MOVE_SPEED", "75");
    this.defaultConfig.setProperty("SCROLL_SPEED", "5");
    this.defaultConfig.setProperty("PRESSES_FOR_BOID", "2");
    this.defaultConfig.setProperty("NUM_WALLS", "8");
    this.defaultConfig.setProperty("MIN_WALL_HEIGHT", "50");
    this.defaultConfig.setProperty("SAFE_ZONE", "100");
    this.defaultConfig.setProperty("PRESSES_FOR_TARGET_MOVE", "2");
    this.defaultConfig.setProperty("MAX_LIVES", "3");
    this.defaultConfig.setProperty("DEATH_IMMUNE_SECONDS", "3");
    this.defaultConfig.setProperty("GAME_OVER_ANIMATION_DURATION", "3");


    //sets loaded config
    loadConfigFrom("flock_config.properties");
    println("Flock config: ");
    println(this.loadedConfig);
  }

  public void setup() {
    flock = new Flock();
    // Add an initial set of boids into the system
    //for (int i = 0; i < this.getIntProp("MAX_FLOCK_SIZE"); i++) {
    //  flock.addBoid(new Boid(width/2, height/2));
    //}

    this.wallManager = new WallManager(this.getIntProp("NUM_WALLS"), this.getIntProp("SCROLL_SPEED"), this.getIntProp("MIN_WALL_HEIGHT"), this.getIntProp("SAFE_ZONE"));
    currentX = width/2;
    currentY = height/2;

    println("MODE: Flock");

    asyncPressCounter = new ArrayList<Integer>();
    for ( int padIndex = 0; padIndex < numPads; padIndex++) {
      asyncPressCounter.add(0);
    }

    newXOffset = 0;
    newYOffset = 0;
    lastScoringTime = System.currentTimeMillis();
    lastDeathTime = 0;
    score = 0;
    highScore = 0;
    iframes = 0;
    lives = this.getIntProp("MAX_LIVES");
    alive = false;
    
    this.font = createFont("Lucidia Grande", 30);
  }

  public void draw() {
    textFont(this.font);
    textSize(30);
    
    for (int padIndex = 0; padIndex < numPads; padIndex++) {
      if (padWasPressed.get(padIndex)) {
        this.resetPressed(padIndex);
        if (pressCounter.get(padIndex) % this.getIntProp("PRESSES_FOR_BOID") == 0 && this.flock.boids.size() < this.getIntProp("MAX_FLOCK_SIZE")) {
          flock.addBoid(new Boid(currentX, currentY));
          alive = true;
        }
      }
    }
    int xTarget = constrain(currentX + newXOffset, 100, width - 100);
    int yTarget = constrain(currentY + newYOffset, 100, height -100);

    noStroke();
    fill(color(110, 255, 255));
    ellipse(xTarget, yTarget, 20, 20);

    //reset white stroke
    stroke(color(0, 0, 255));
    noFill();


    this.flock.run(xTarget, yTarget);
    this.wallManager.run(this.flock);

    //update cursor
    this.currentX = xTarget;
    this.currentY = yTarget;

    //reset midi input offsets
    this.newXOffset = 0;
    this.newYOffset = 0;

    //death animation
    long currentTime = System.currentTimeMillis();
    if (currentTime - lastDeathTime < this.getIntProp("GAME_OVER_ANIMATION_SECONDS") * 1000) {
      textAlign(CENTER);
      fill(color(0, 255, 255));
      textSize(40);

      text("GAME OVER", width/2, height/2);

      //reset text settings
      textSize(30);
      textAlign(LEFT);
      fill(color(0, 0, 255));        
      noFill();

      //lose life
    } else if (flock.boids.size() == 0 && iframes <= 0 && alive) {
      lives--;      
      iframes =  this.getIntProp("DEATH_IMMUNE_SECONDS") * (int) frameRate; 
      if (lives == 0) {
        lives = this.getIntProp("MAX_LIVES");
        lastDeathTime = currentTime;
      }
      score = 0;
      alive = false;
      this.currentX = width/2;
      this.currentY = height/2;
      // increment score
    } else if (currentTime - lastScoringTime >= 1000) {
      score += flock.boids.size();
      if (score > highScore) {
        highScore = score;
      }
      lastScoringTime = currentTime;
    } 

    //write score
    fill(color(0, 0, 255));
    text(score, 100, 50);
    fill(color(0, 255, 255));
    text(highScore, 200, 50);
    fill(color(0, 0, 255));
    noFill();

    //write lives
    noStroke();
    fill(color(110, 255, 255));
    for (int i = 0; i < lives - 1; i++) {
      ellipse(width - 200 + (50 * i), 50, 20, 20);
    }

    fill(color(0, 0, 255));        
    noFill();
    
    if (iframes >= 0){
      iframes--;
    }
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {
    
    if (pad != null && vel > 0) {
      //Count consecutive presses on single pad
      //Similar to pressCounter, but updated by callback instead of in draw()
      this.asyncPressCounter.set(pad.index, asyncPressCounter.get(pad.index) + 1);
      for (int otherPad = 0; otherPad < numPads; otherPad++) {
        if (otherPad != pad.index) {
          this.asyncPressCounter.set(otherPad, 0);
        }
      }

      //Move target
      if (asyncPressCounter.get(pad.index) % this.getIntProp("PRESSES_FOR_TARGET_MOVE") == 0) {
        switch (pad.name) {
        case "TOP_RIGHT_NOTE" :
          this.newYOffset -= this.getIntProp("MOVE_SPEED");
          this.newXOffset += this.getIntProp("MOVE_SPEED");
          break;

        case "TOP_LEFT_NOTE" :
          this.newYOffset -= this.getIntProp("MOVE_SPEED");
          this.newXOffset -= this.getIntProp("MOVE_SPEED");
          break;

        case "BOTTOM_LEFT_NOTE" :
          this.newYOffset += this.getIntProp("MOVE_SPEED");
          this.newXOffset -= this.getIntProp("MOVE_SPEED");
          break;

        case "BOTTOM_RIGHT_NOTE" :
          this.newYOffset += this.getIntProp("MOVE_SPEED");
          this.newXOffset += this.getIntProp("MOVE_SPEED");
          break;
        }
      }
    }
  }
}

// The Walls (a list of Wall objects)
private class WallManager {
  private int numWalls;
  private int scrollSpeed;  
  private int minWallHeight;
  private int maxWallHeight;
  private int xOffset;
  private List<Integer> topWalls;
  private List<Integer> bottomWalls;
  private int wallWidth;
  private int safeZone;

  public WallManager(int numWalls, int scrollSpeed, int minWallHeight, int safeZone) {
    this.numWalls = numWalls;

    //subtract by one because first and last wall will always add up to one wallWidth
    this.wallWidth = width/(numWalls-1);
    this.scrollSpeed = scrollSpeed;
    this.minWallHeight = minWallHeight;
    this.maxWallHeight = height - minWallHeight - safeZone;
    this.xOffset = this.wallWidth;
    this.safeZone = safeZone;

    //initialize walls
    this.topWalls = new ArrayList<Integer>();
    this.bottomWalls = new ArrayList<Integer>();
    int prevTop = height/2 - safeZone;
    int prevBottom = height/2 - safeZone;
    for (int i = 0; i < this.numWalls; i++) {
      //Top walls
      //make sure there is continuous path
      int maxTopForContinuity = height - (prevBottom + this.safeZone);
      int top = (int)random(minWallHeight, min( maxWallHeight, maxTopForContinuity));
      this.topWalls.add(top);

      //Bottom walls
      //make sure there is continuous path
      int maxBottomForContinuity = height - (prevTop + safeZone);
      int maxBottomForGap = height - (top + this.safeZone);
      //make sure there is also enough space between top and bottom walls 
      int bottom = (int) random(this.minWallHeight, min(this.maxWallHeight, maxBottomForContinuity, maxBottomForGap));
      this.bottomWalls.add(bottom);

      prevTop = top;
      prevBottom = bottom;
    }
  }

  public void run(Flock f) {
    this.scroll();
    this.collide(f);
    this.render();
  }

  public void scroll() {
    this.xOffset -= this.scrollSpeed;

    //Create new walls
    if (this.xOffset <= 0) {
      Collections.rotate(this.topWalls, -1);
      Collections.rotate(this.bottomWalls, -1);

      //Top walls
      int prevBottom = this.bottomWalls.get(this.numWalls - 2);
      //make sure there is continuous path
      int maxTopForContinuity = height - (prevBottom + this.safeZone);
      int top = (int)random(minWallHeight, min( this.maxWallHeight, maxTopForContinuity));
      this.topWalls.set(this.topWalls.size() - 1, top);

      //Bottom walls
      int prevTop = this.topWalls.get(this.numWalls - 2);
      //make sure there is continuous path
      int maxBottomForContinuity = height - (prevTop + this.safeZone);
      int maxBottomForGap = height - (top + this.safeZone);
      //make sure there is also enough space between top and bottom walls 
      int bottom = (int) random(this.minWallHeight, min(this.maxWallHeight, maxBottomForContinuity, maxBottomForGap));
      this.bottomWalls.set(this.topWalls.size() - 1, bottom);

      //println(top, bottom);      
      //reset offset
      this.xOffset = this.wallWidth;
    }
  }

  public void render() {
    //first (partial) walls
    rect(0, 0, this.xOffset, this.topWalls.get(0));
    rect(0, height - this.bottomWalls.get(0), this.xOffset, this.bottomWalls.get(0));

    //full walls
    int lastFullRectEndX = 0;
    for (int i = 1; i < this.numWalls - 1; i++) {
      int fromTop = this.topWalls.get(i);
      int fromBottom = this.bottomWalls.get(i);

      rect((i - 1) * this.wallWidth + this.xOffset, 0, this.wallWidth, fromTop);
      rect((i - 1) * this.wallWidth + this.xOffset, height - fromBottom, this.wallWidth, fromBottom);
      lastFullRectEndX = (i - 1) * this.wallWidth + this.xOffset + this.wallWidth;
    }

    //last (partial) walls
    int lastWidth = width - lastFullRectEndX - 1;
    rect(width - lastWidth - 1, 0, lastWidth, this.topWalls.get(this.numWalls - 1));
    rect(width - lastWidth - 1, height - this.bottomWalls.get(this.numWalls - 1), lastWidth, this.bottomWalls.get(this.numWalls - 1));
  }

  public void collide(Flock f) {
    ArrayList<Boid> toRemove = new ArrayList<Boid>();
    for (Boid b : f.boids) {
      int wallIndex = (int) ((b.position.x + (this.wallWidth - this.xOffset)) / this.wallWidth);
      if (this.topWalls.get(wallIndex) > b.position.y) {
        //delete boid
        toRemove.add(b);
      } else if (this.bottomWalls.get(wallIndex) > height - b.position.y) {
        //delete boid
        toRemove.add(b);
      }
    }
    for (Boid b : toRemove) {
      f.boids.remove(b);
    }
  }
}

//Code copied from https://processing.org/examples/flocking.html
// The Flock (a list of Boid objects)
private class Flock {
  public ArrayList<Boid> boids; // An ArrayList for all the boids

  Flock() {
    boids = new ArrayList<Boid>(); // Initialize the ArrayList
  }

  void run(int xTarget, int yTarget) {
    for (Boid b : boids) {
      b.run(boids, xTarget, yTarget);  // Passing the entire list of boids to each boid individually
    }
  }

  void addBoid(Boid b) {
    boids.add(b);
  }
}

//Code copied and modified from https://processing.org/examples/flocking.html
// The Boid class

private class Boid {

  PVector position;
  PVector velocity;
  PVector acceleration;
  float r;
  float maxforce;    // Maximum steering force
  float maxspeed;    // Maximum speed

  Boid(float x, float y) {
    acceleration = new PVector(0, 0);

    // This is a new PVector method not yet implemented in JS
    // velocity = PVector.random2D();

    // Leaving the code temporarily this way so that this example runs in JS
    float angle = random(TWO_PI);
    velocity = new PVector(cos(angle), sin(angle));

    position = new PVector(x, y);
    r = 2.0;
    maxspeed = 2;
    maxforce = 0.03;
  }

  void run(ArrayList<Boid> boids, int xTarget, int yTarget) {
    flock(boids, xTarget, yTarget);
    update();
    borders();
    render();
  }

  void applyForce(PVector force) {
    // We could add mass here if we want A = F / M
    acceleration.add(force);
  }

  // We accumulate a new acceleration each time based on three rules
  void flock(ArrayList<Boid> boids, int xTarget, int yTarget) {
    PVector sep = separate(boids);   // Separation
    PVector ali = align(boids);      // Alignment
    PVector coh = cohesion(boids);   // Cohesion
    PVector gid = seek(new PVector(xTarget, yTarget)); //Guide
    // Arbitrarily weight these forces
    sep.mult(1.5);
    ali.mult(1.0);
    coh.mult(1.0);
    gid.mult(3.0);
    // Add the force vectors to acceleration
    applyForce(sep);
    applyForce(ali);
    applyForce(coh);
    applyForce(gid);
  }

  // Method to update position
  void update() {
    // Update velocity
    velocity.add(acceleration);
    // Limit speed
    velocity.limit(maxspeed);
    position.add(velocity);
    // Reset accelertion to 0 each cycle
    acceleration.mult(0);
  }

  // A method that calculates and applies a steering force towards a target
  // STEER = DESIRED MINUS VELOCITY
  PVector seek(PVector target) {
    PVector desired = PVector.sub(target, position);  // A vector pointing from the position to the target
    // Scale to maximum speed
    desired.normalize();
    desired.mult(maxspeed);

    // Above two lines of code below could be condensed with new PVector setMag() method
    // Not using this method until Processing.js catches up
    // desired.setMag(maxspeed);

    // Steering = Desired minus Velocity
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(maxforce);  // Limit to maximum steering force
    return steer;
  }

  void render() {
    // Draw a triangle rotated in the direction of velocity
    float theta = velocity.heading2D() + radians(90);
    // heading2D() above is now heading() but leaving old syntax until Processing.js catches up

    fill(200, 100);
    stroke(255);
    pushMatrix();
    translate(position.x, position.y);
    rotate(theta);
    beginShape(TRIANGLES);
    vertex(0, -r*2);
    vertex(-r, r*2);
    vertex(r, r*2);
    endShape();
    popMatrix();
    noFill();
  }

  // Wraparound
  void borders() {
    if (position.x < -r) position.x = width+r;
    if (position.y < -r) position.y = height+r;
    if (position.x > width+r) position.x = -r;
    if (position.y > height+r) position.y = -r;
  }

  // Separation
  // Method checks for nearby boids and steers away
  PVector separate (ArrayList<Boid> boids) {
    float desiredseparation = 25.0f;
    PVector steer = new PVector(0, 0, 0);
    int count = 0;
    // For every boid in the system, check if it's too close
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
      // If the distance is greater than 0 and less than an arbitrary amount (0 when you are yourself)
      if ((d > 0) && (d < desiredseparation)) {
        // Calculate vector pointing away from neighbor
        PVector diff = PVector.sub(position, other.position);
        diff.normalize();
        diff.div(d);        // Weight by distance
        steer.add(diff);
        count++;            // Keep track of how many
      }
    }
    // Average -- divide by how many
    if (count > 0) {
      steer.div((float)count);
    }

    // As long as the vector is greater than 0
    if (steer.mag() > 0) {
      // First two lines of code below could be condensed with new PVector setMag() method
      // Not using this method until Processing.js catches up
      // steer.setMag(maxspeed);

      // Implement Reynolds: Steering = Desired - Velocity
      steer.normalize();
      steer.mult(maxspeed);
      steer.sub(velocity);
      steer.limit(maxforce);
    }
    return steer;
  }

  // Alignment
  // For every nearby boid in the system, calculate the average velocity
  PVector align (ArrayList<Boid> boids) {
    float neighbordist = 50;
    PVector sum = new PVector(0, 0);
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
      if ((d > 0) && (d < neighbordist)) {
        sum.add(other.velocity);
        count++;
      }
    }
    if (count > 0) {
      sum.div((float)count);
      // First two lines of code below could be condensed with new PVector setMag() method
      // Not using this method until Processing.js catches up
      // sum.setMag(maxspeed);

      // Implement Reynolds: Steering = Desired - Velocity
      sum.normalize();
      sum.mult(maxspeed);
      PVector steer = PVector.sub(sum, velocity);
      steer.limit(maxforce);
      return steer;
    } else {
      return new PVector(0, 0);
    }
  }

  // Cohesion
  // For the average position (i.e. center) of all nearby boids, calculate steering vector towards that position
  PVector cohesion (ArrayList<Boid> boids) {
    float neighbordist = 50;
    PVector sum = new PVector(0, 0);   // Start with empty vector to accumulate all positions
    int count = 0;
    for (Boid other : boids) {
      float d = PVector.dist(position, other.position);
      if ((d > 0) && (d < neighbordist)) {
        sum.add(other.position); // Add position
        count++;
      }
    }
    if (count > 0) {
      sum.div(count);
      return seek(sum);  // Steer towards the position
    } else {
      return new PVector(0, 0);
    }
  }
}
