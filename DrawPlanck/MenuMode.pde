public class MenuMode extends Mode {

  private List<String> menu = new ArrayList<String>();

  private int choiceIndex;
  private int menuIndex;
  final private int titleVerticalMargin = 65; 
  final private int planckHeight = height - titleVerticalMargin; 
  final private int positions[][] = {{width/4, planckHeight/4 + titleVerticalMargin}, {3*width/4, planckHeight/4 + titleVerticalMargin}, {width/4, 3*planckHeight/4 + titleVerticalMargin}, {3*width/4, 3*planckHeight/4 + titleVerticalMargin}};
  final private int cornerPositionFlags[][] = {{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 0, 1}, {0, 0, 1, 0} };
  final private PFont menuFont;
  final private PFont menuBoldFont;


  private PImage bgImage;
  private PGraphics pg;

  public MenuMode() {
    this.modeName = "Menu";

    //sets loaded config
    this.loadConfigFrom("menu_config.properties");
    println("Menu config: ");
    println(this.loadedConfig);
    menuFont = createFont("Arial", 32);

    menuBoldFont = createFont("Arial Bold", 32);

    //Create background and scale to screen while keeping proportions
    this.pg = createGraphics(width, height);
    this.bgImage = loadImage("menu_bg.jpg");    
    this.pg.beginDraw();
    this.pg.background(0);
    bgImage.resize(width, 0);      
    if (bgImage.height < height) {
      bgImage.resize(0, height);
    }
    this.pg.imageMode(CENTER);
    this.pg.image(bgImage, width/2, height/2);
    this.pg.endDraw();
  }

  public void setup() {
    System.out.println("MODE: Menu");

    this.choiceIndex = -1;
    this.menuIndex = 0;
  }

  public void draw() {
    this.noModePressChecking();
    background(this.pg);
    textAlign(CENTER);

    //select mode
    if (choiceIndex >= 0 && ((menuIndex * 3) + choiceIndex) < modes.size() - 1) {
      nextMode =(menuIndex * 3) + choiceIndex + 1;
    } else {
      //Draw choices
      textFont(menuBoldFont);
      textSize(48);
      text("Rythmes visuels - Rhythm Visuals", width/2, titleVerticalMargin);

      textFont(menuFont);
      textSize(32);

      int optionIndex = 0;
      final int rectCornerRadi = 90;
      while (optionIndex < 3) {        
        //+1 to ignore first mode which should be menu itself
        rectMode(CENTER);
        fill(160, 255, 255, 230);
        noStroke();
        rect(positions[optionIndex][0], positions[optionIndex][1], (int) width/2.1, (int) planckHeight/2.2, 
          cornerPositionFlags[optionIndex][0]*rectCornerRadi + 3, 
          cornerPositionFlags[optionIndex][1]*rectCornerRadi + 3, 
          cornerPositionFlags[optionIndex][2]*rectCornerRadi + 3, 
          cornerPositionFlags[optionIndex][3]*rectCornerRadi + 3);
        fill(0, 0, 255, 255);
        stroke(0, 0, 255, 255);
        if (((menuIndex * 3) + optionIndex) < modes.size() - 1) {
          text(modes.get((menuIndex * 3) + optionIndex + 1).modeName, positions[optionIndex][0], positions[optionIndex][1]);
        }
        optionIndex++;
      }



      fill(160, 255, 255, 230);
      noStroke();
      rect(positions[optionIndex][0], positions[optionIndex][1], (int) width/2.1, (int) planckHeight/2.2, 
        cornerPositionFlags[3][0]*rectCornerRadi + 3, 
        cornerPositionFlags[3][1]*rectCornerRadi + 3, 
        cornerPositionFlags[3][2]*rectCornerRadi + 3, 
        cornerPositionFlags[3][3]*rectCornerRadi + 3);   
      rectMode(CORNER);
      fill(0, 0, 255, 255);
      stroke(0, 0, 255, 255);
      textFont(menuBoldFont);
      text("...", positions[3][0], positions[3][1]);


      //write instructions on top left pad
      textFont(menuFont);
      textSize(22);
      text("Maintenir ce pad pour revenir au menu", positions[0][0], positions[0][1]+62);
      text("Hold this pad to return to menu", positions[0][0], positions[0][1]+88);
    }
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {    
    //filter out unassigned notes, note_off messages and unused pads
    if (pad != null && vel > 0) {
      switch (pad.name) {
      case "BOTTOM_RIGHT_NOTE" :
        if (menuIndex + 1 <  Math.ceil((modes.size() - 1) / 3.0)) {
          menuIndex++;
        } else {
          menuIndex = 0;
        }
        break;
      case "TOP_LEFT_NOTE":
        choiceIndex = 0;
        break;
      case "TOP_RIGHT_NOTE":
        choiceIndex = 1;
        break;
      case "BOTTOM_LEFT_NOTE":
        choiceIndex = 2;
        break;
      }
    }
  }
}
