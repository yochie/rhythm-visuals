public class WordMode extends Mode {

  private List<String> words = new ArrayList<String>();

  private int pressCount;
  private int wordIndex;
  private int textX;
  private int textY;
  private PFont font;
  private float alpha;

  public WordMode() {
    this.modeName = "Impro / Jam";

    this.defaultConfig.setProperty("WORDS", "Triolets, Gigue, Lentement, Rapidement");
    this.defaultConfig.setProperty("PRESSES_FOR_WORD_SWITCH", "30");


    //sets loaded config
    this.loadConfigFrom("word_config.properties");
    println("Word config: ");
    println(this.loadedConfig);

    //parse words list from config
    this.words = Arrays.asList(this.loadedConfig.getProperty("WORDS").split("\\s*,\\s*"));
    println("Available fonts: ");
    println(PFont.list());
  }

  public void setup() {
    System.out.println("MODE: Word");

    // The font must be located in the sketch's 
    // "data" directory to load successfully
    font = createFont(this.loadedConfig.getProperty("FONT_NAME"), this.getIntProp("FONT_SIZE"));
    textFont(font);
    textAlign(CENTER);
    this.alpha = 255;
    this.textX = (int) (width/2 + random(-75, 75));
    this.textY = (int) (height/2 + random(-75, 75));
    
    this.pressCount = 0;
    this.wordIndex = (int) (random(this.words.size()));

  }

  public void draw() {
    this.noModePressChecking();
    textFont(font);
    textAlign(CENTER);
    
    //Tint using bpm
    float constrainedBpm = constrain(currentBpm, 40, 150);
    int newColor = Math.round(map(constrainedBpm, 40, 150, 255, 0));
    fill(newColor, 255, 255, 30);
    noStroke();
    rect(0, 0, width, height);
    
    //change word
    if (this.pressCount == this.getIntProp("PRESSES_FOR_WORD_SWITCH")) {    
      this.pressCount = 0;
      this.textX = (int) (width/2 + random(-75, 75));
      this.textY = (int) (height/2 + random(-75, 75));
      this.alpha = 255;
      //cycle index
      int oldIndex = this.wordIndex;
      do {
        this.wordIndex = (int) (random(this.words.size()));
      } while (this.wordIndex == oldIndex);

      fill(this.getIntProp("FONT_HUE"), 255, 255, this.alpha);
    } 

    //write text
    fill(this.getIntProp("FONT_HUE"), 255, 255, this.alpha);
    this.alpha *= this.getFloatProp("ALPHA_REDUCTION");
    text(this.words.get(this.wordIndex), this.textX, this.textY);
    noFill();
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {    

    //filter out unassigned notes, note_off messages and unused pads
    if (pad != null && vel > 0 && pad.name.equals(this.getStringProp("SWITCH_PAD_NAME"))) {
      this.pressCount++;
    } else if (vel > 0) {
      this.pressCount = 0;
    }
  }
}
