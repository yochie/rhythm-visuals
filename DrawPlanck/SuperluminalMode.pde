import java.util.Properties; //<>//

public class SuperluminalMode extends Mode {

  private ArrayList<Star> stars;

  public SuperluminalMode() {

    // TODO check how to set a bool prop
    this.defaultConfig.setProperty("BG_STARS", "1");
    this.defaultConfig.setProperty("BG_STARS_NUMBER", "4");
    this.defaultConfig.setProperty("BG_STARS_SPEED", "30");

    this.defaultConfig.setProperty("STARS1_WIDTH", "10");
    this.defaultConfig.setProperty("STARS2_WIDTH", "25");
    this.defaultConfig.setProperty("STARS3_WIDTH", "40");
    this.defaultConfig.setProperty("STARS4_WIDTH", "60");
    
    this.defaultConfig.setProperty("STARS1_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS2_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS3_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS4_SPEED", "0.95");
    
    //TODO (play with doppler effect? Use config or random?)
    this.defaultConfig.setProperty("STARS1_COLOR", "30");
    this.defaultConfig.setProperty("STARS2_COLOR", "150");
    this.defaultConfig.setProperty("STARS3_COLOR", "200");
    this.defaultConfig.setProperty("STARS4_COLOR", "80");

    //midi controller specific, usually 255 but our Planck caps earlier
    this.defaultConfig.setProperty("MAX_VELOCITY", "100");
    this.defaultConfig.setProperty("STAR_THICKNESS", "1");

    //sets loaded config
    loadConfigFrom("superluminal_config.properties");
    println("Supraluminal config: ");
    println(loadedConfig);
  }

  public void setup() {
    System.out.println("MODE: Supraluminal");
    stroke(0, 255, 0);
    stars = new ArrayList<Star>();
  }

  //Create stars when a sensor was pressed and keep them moving
  public void draw() {

    int starNumber;
    float starGrowFactor;
    int starSpeed;

    //create constant stars flow in background if config ON
    if(this.getIntProp("BG_STARS") == 1) {
        for (int i = 0; i < this.getIntProp("BG_STARS_NUMBER"); i++) {
          stars.add(new Star(
            0, //do not grow
            this.getIntProp("BG_STARS_SPEED"),
            this.getIntProp("STAR_THICKNESS")
          ));
        }
    }

    for (int pad = 0; pad < numPads; pad++) {

      //create stars
      if (padWasPressed.get(pad)) {

        //set stars params depending on pad
        switch(pad) {
          case 1:
            starNumber = this.getIntProp("STARS1_NUMBER");
            starGrowFactor = this.getFloatProp("STARS1_GROW_FACTOR");
            starSpeed = this.getIntProp("STARS1_SPEED");
            break;
          case 2:
            starNumber = this.getIntProp("STARS2_NUMBER");
            starGrowFactor = this.getFloatProp("STARS2_GROW_FACTOR");
            starSpeed = this.getIntProp("STARS2_SPEED");
            break;
          case 3:
            starNumber = this.getIntProp("STARS3_NUMBER");
            starGrowFactor = this.getFloatProp("STARS3_GROW_FACTOR");
            starSpeed = this.getIntProp("STARS3_SPEED");
            break;
          case 4:
            starNumber = this.getIntProp("STARS4_NUMBER");
            starGrowFactor = this.getFloatProp("STARS4_GROW_FACTOR");
            starSpeed = this.getIntProp("STARS4_SPEED");
            break;
          default:
            starNumber = this.getIntProp("STARS1_NUMBER");
            starGrowFactor = this.getFloatProp("STARS1_GROW_FACTOR");
            starSpeed = this.getIntProp("STARS1_SPEED");
            println("Pad " + pad + " is not assigned - Falling to star1 config");
            break;
        }
        // TODO: check how to set dynamic vars with processing - could replace switch if possible

        for (int i = 0; i < starNumber; i++) {
          stars.add(new Star(
            starGrowFactor,
            starSpeed,
            this.getIntProp("STAR_THICKNESS"))
          );
        }

      }

    }

    //maintain stars movement
    for (int i = 0; i < stars.size(); i++) {
      Star star = stars.get(i);
      star.update();
      //remove out of screen stars - TODO => debug & FIX: biggest stars not removed / removed after a very long time
      if(!star.visible) {
        stars.remove(i);
      }
    }
    printArray(stars);
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {
    // Do something on MIDI msg received
    // TODO: affect velocity changes to stars number
  }

}

//based on https://processing.org/examples/bounce.html
//and https://processing.org/examples/accelerationwithvectors.html
private class Star {

  private boolean visible = true;

  // Always start at center
  private PVector location = new PVector(width/2,height/2);
  private PVector velocity;
  private PVector acceleration;
  private PVector destination;
  private float topspeed;

  private float growfactor;
  private float starThickness;
  private float rad;
  private int circleColor = 0;

  public Star(float starGrowFactor, int speed, int starThickness) {

    this.velocity = new PVector(0,0);
    this.topspeed = speed;
    float destX = random(width);
    float destY = height*random(0,1);
    this.destination = new PVector(destX,destY);
    //this.destination = PVector.random2D();
    this.acceleration = PVector.sub(this.destination,this.location);

    this.rad = 1;
    this.growfactor = starGrowFactor;
    this.starThickness = starThickness;
    // TODO make color change - use config or random?
    this.circleColor = (int)random(140, 190);
  }

  public void update() {

    // Velocity changes according to acceleration
    this.velocity.add(this.acceleration);
    // Limit the velocity by topspeed
    this.velocity.limit(this.topspeed);
    // Location changes by velocity
    this.location.add(this.velocity);
    
    // Update size and color of the star
    this.rad = this.rad + this.growfactor;
    this.circleColor = this.circleColor + 3;
      
    // Check if the star is still visible
    if (this.location.x > width+this.rad/2 || this.location.x < -this.rad/2) {
      this.visible = false;
    }
    if (this.location.y > height+this.rad/2 || this.location.y < -this.rad/2) {
      this.visible = false;
    }

    // Draw the shape
    stroke(color(this.circleColor, 255, 255));
    strokeWeight(this.starThickness);
    //fill(25);
    ellipse(this.location.x,this.location.y,this.rad, this.rad);
  }
 
}
