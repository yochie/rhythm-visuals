public class WordMode extends Mode {

  private List<String> words = new ArrayList<String>();
  private List<String> wordsAlt = new ArrayList<String>();
  private List<String> wordsAlt2 = new ArrayList<String>();


  private int pressCount;
  private int pressCountAlt;
  private int pressCountAlt2;


  private int wordIndex;
  private int wordIndexAlt;
  private int wordIndexAlt2;

  private int currentBank;

  private int textX;
  private int textY;
  private PFont font;
  private float alpha;
  private int oldColor;

  public WordMode() {
    this.modeName = "Impro - Jam";

    this.defaultConfig.setProperty("WORDS", "Triolets, Gigue, Lentement, Rapidement");
    this.defaultConfig.setProperty("WORDS_ALT", "");
    this.defaultConfig.setProperty("WORDS_ALT_2", "");


    this.defaultConfig.setProperty("PRESSES_FOR_WORD_SWITCH", "30");
    this.defaultConfig.setProperty("PRESSES_FOR_WORD_SWITCH_ALT", "30");
    this.defaultConfig.setProperty("PRESSES_FOR_WORD_SWITCH_ALT_2", "30");


    this.defaultConfig.setProperty("SWITCH_PAD_NAME", "TOP_LEFT_NOTE");
    this.defaultConfig.setProperty("SWITCH_PAD_NAME_ALT", "TOP_RIGHT_NOTE");
    this.defaultConfig.setProperty("SWITCH_PAD_NAME_ALT_2", "BOTTOM_LEFT_NOTE");

    this.defaultConfig.setProperty("FONT_SIZE", "90");
    this.defaultConfig.setProperty("FONT_NAME", "Perpetua gras");
    this.defaultConfig.setProperty("FONT_HUE", "50");
    this.defaultConfig.setProperty("ALPHA_REDUCTION", "0.99");

    //sets loaded config
    this.loadConfigFrom("word_config.properties");
    println("Word config: ");
    println(this.loadedConfig);

    //parse words list from config
    this.words = Arrays.asList(this.loadedConfig.getProperty("WORDS").split("\\s*,\\s*"));
    this.wordsAlt = Arrays.asList(this.loadedConfig.getProperty("WORDS_ALT").split("\\s*,\\s*"));
    this.wordsAlt2 = Arrays.asList(this.loadedConfig.getProperty("WORDS_ALT_2").split("\\s*,\\s*"));


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
    this.textX = (int) (width/2 + random(-width/4, width/4));
    this.textY = (int) (height/2 + random(-height/4, height/4));

    this.pressCount = 0;
    this.pressCountAlt = 0;
    this.pressCountAlt2 = 0;

    this.wordIndex = (int) (random(this.words.size()));
    this.wordIndexAlt = (int) (random(this.wordsAlt.size()));
    this.wordIndexAlt2 = (int) (random(this.wordsAlt2.size()));

    this.oldColor =  -1;
    currentBank = -1;
  }

  public void draw() {
    this.noModePressChecking();
    textFont(font);
    textAlign(CENTER);

    //Tint using bpm
    float constrainedBpm = constrain(currentBpm, 40, 150);
    int newColor = Math.round(map(constrainedBpm, 40, 150, 85, 0));

    //first time
    if (oldColor < 0) 
      oldColor = newColor;

    int newInterpolatedColor = Math.round(lerp(oldColor, newColor, 0.05));

    oldColor = newInterpolatedColor;
    fill(newInterpolatedColor, 255, 255, 128);
    noStroke();
    rect(0, 0, width, height);


    //change word    
    boolean switchFromBank = this.pressCount == this.getIntProp("PRESSES_FOR_WORD_SWITCH");
    boolean switchFromBankAlt = this.pressCountAlt == this.getIntProp("PRESSES_FOR_WORD_SWITCH_ALT");
    boolean switchFromBankAlt2 = this.pressCountAlt2 == this.getIntProp("PRESSES_FOR_WORD_SWITCH_ALT_2");

    if (switchFromBank) {
      this.wordIndex = this.changeWord(this.wordIndex, this.words);
      this.currentBank = 0;
    } else if (switchFromBankAlt) {
      this.wordIndexAlt = this.changeWord(this.wordIndexAlt, this.wordsAlt);
      this.currentBank = 1;
    } else if (switchFromBankAlt2) {
      this.wordIndexAlt2 = this.changeWord(this.wordIndexAlt2, this.wordsAlt2);
      this.currentBank = 2;
    }

    //write text
    fill(this.getIntProp("FONT_HUE"), 255, 255, this.alpha);
    this.alpha *= this.getFloatProp("ALPHA_REDUCTION");

    if (currentBank == 0) {
      text(this.words.get(this.wordIndex), this.textX, this.textY);
    } else if (currentBank == 1) {
      text(this.wordsAlt.get(this.wordIndexAlt), this.textX, this.textY);
    } else if (currentBank == 2) {
      text(this.wordsAlt2.get(this.wordIndexAlt2), this.textX, this.textY);
    }
    noFill();
  }

  private int changeWord(int oldIndex, List<String> wordBank) {

    int bankSize = wordBank.size();
    this.pressCount = 0;
    this.pressCountAlt = 0;
    this.pressCountAlt2 = 0;
    int newIndex = oldIndex + 1;
    if (newIndex == bankSize) {
      newIndex = 0;
      Collections.shuffle(wordBank);
    }

    //do {
    //  newIndex = (int) (random(bankSize));
    //} while (newIndex == oldIndex);

    this.textX = (int) (width/2 + random(-width/4, width/4));
    this.textY = (int) (height/2 + random(-height/4, height/4));
    this.alpha = 255;
    fill(this.getIntProp("FONT_HUE"), 255, 255, this.alpha);

    return newIndex;
  }

  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad) {    

    //filter out unassigned notes, note_off messages and unused pads
    if (pad != null && vel > 0) {
      if (pad.name.equals(this.getStringProp("SWITCH_PAD_NAME"))) {
        this.pressCount++;
      } else if (pad.name.equals(this.getStringProp("SWITCH_PAD_NAME_ALT"))) {
        this.pressCountAlt++;
      } else if (pad.name.equals(this.getStringProp("SWITCH_PAD_NAME_ALT_2"))) {
        this.pressCountAlt2++;
      } else if (vel > 0) {
        this.pressCount = 0;
        this.pressCountAlt = 0;
        this.pressCountAlt2 = 0;
      }
    }
  }
}
