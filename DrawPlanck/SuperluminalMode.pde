import java.util.Properties; //<>//

public class SuperluminalMode extends Mode {

  private ArrayList<Star> stars;

  public SuperluminalMode() {
    this.defaultConfig.setProperty("STARS1_WIDTH", "10");
    this.defaultConfig.setProperty("STARS2_WIDTH", "25");
    this.defaultConfig.setProperty("STARS3_WIDTH", "40");
    this.defaultConfig.setProperty("STARS4_WIDTH", "60");
    
    this.defaultConfig.setProperty("STARS1_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS2_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS3_SPEED", "0.95");
    this.defaultConfig.setProperty("STARS4_SPEED", "0.95");
    
    //TODO (play with doppler effect?)
    this.defaultConfig.setProperty("STARS1_COLOR", "30");
    this.defaultConfig.setProperty("STARS2_COLOR", "150");
    this.defaultConfig.setProperty("STARS3_COLOR", "200");
    this.defaultConfig.setProperty("STARS4_COLOR", "80");
   
    this.defaultConfig.setProperty("PRESSES_FOR_STARS", "2"); // TODO remove
    this.defaultConfig.setProperty("MAX_STARS", "20"); // TODO remove

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

    for (int pad = 0; pad < numPads; pad++) {

      if (padWasPressed.get(pad)) {

        //create star
        if (pressCounter.get(pad) % this.getIntProp("PRESSES_FOR_STARS") == 0 && stars.size() < this.getIntProp("MAX_STARS")) {
            int starGrowFactor = 0; // TODO check how to init vars without vals in processing :)
            int starSpeed = 20;
            switch(pad) {
              case 1: 
                println("pad1");
                starGrowFactor = this.getIntProp("STARS1_GROW_FACTOR");
                starSpeed = this.getIntProp("STARS1_SPEED");
                break;
              case 2: 
                println("pad2");
                starGrowFactor = this.getIntProp("STARS2_GROW_FACTOR");
                starSpeed = this.getIntProp("STARS2_SPEED");
                break;
              case 3: 
                println("pad3");
                starGrowFactor = this.getIntProp("STARS3_GROW_FACTOR");
                starSpeed = this.getIntProp("STARS3_SPEED");
                break;
              case 4: 
                println("pad4");
                starGrowFactor = this.getIntProp("STARS4_GROW_FACTOR");
                starSpeed = this.getIntProp("STARS4_SPEED");
                break;
              default:
                println("Pad is not assigned - Index: " + pad);
                break;
            }
            // TODO: check how to set dynamic vars with processing - could replace switch if possible
            
            stars.add(new Star(pad,
            width/2,
            height/2,
            starGrowFactor,
            starSpeed,
            this.getIntProp("STAR_THICKNESS"))
            );
        }

      }

    }

    //maintain stars movement
    for (Star star : stars) {
      star.update();
    }
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {
    // Do something on MIDI msg received
  }

}

//based on https://processing.org/examples/bounce.html
private class Star {
  private int master;
  private int growfactor;
  private float starThickness;

  private int rad;           // Width of the shape
  private float xpos, ypos;  // Starting position of shape    

  private float xspeed;  // Speed of the shape
  private float yspeed;  // Speed of the shape

  private int xdirection = 1;  // Left or Right
  private int ydirection = 1;  // Top to Bottom
  private int circleColor = 0;

  public Star(int master, int xpos, int ypos, int starGrowFactor, int speed, int starThickness) {
    this.master = master;
    this.rad = 1;
    this.growfactor = starGrowFactor;
    this.starThickness = starThickness;
    this.xpos = xpos;
    this.ypos = ypos;
    this.xspeed = speed;
    this.yspeed = speed;
    // TODO make color change
    this.circleColor = (int)random(50, 120);
    // TODO make all directions available randomly
    this.xdirection = (int) pow(-1, (int) random(1, 3));
    this.ydirection = (int) pow(-1, (int) random(1, 3));
  }

  public void update() {
    
    // Update the position and size of the shape
    this.xpos = this.xpos + ( this.xspeed * this.xdirection );
    this.ypos = this.ypos + ( this.yspeed * this.ydirection );
    this.rad = this.rad + this.growfactor;
      
    // Test to see if the shape exceeds the boundaries of the screen
    // If it does, remove from array TODO
    if (this.xpos > width-this.rad || this.xpos < this.rad) {
      //this.xdirection *= -1;
      //println("OUT X");
    }
    if (ypos > height-rad || ypos < rad) {
      //this.ydirection *= -1;
      //println("OUT Y");
    }

    // Draw the shape
    stroke(color(this.circleColor, 255, 255));
    strokeWeight(starThickness);
    ellipse(this.xpos, this.ypos, this.rad, this.rad);
  }
 
}
