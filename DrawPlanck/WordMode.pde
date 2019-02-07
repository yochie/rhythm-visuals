public class WordMode extends Mode { //<>//
  
  private List<String> words = new ArrayList<String>();
  
  private int pressCount = 0;
  private int wordIndex = 0;


  public WordMode() {
    this.defaultConfig.setProperty("WORDS", "Triolets, Gigue, Lentement, Rapidement");
    this.defaultConfig.setProperty("PRESSES_FOR_WORD_SWITCH", "30");


    //sets loaded config
    this.loadConfigFrom("word_config.properties");
    println("Word config: ");
    println(this.loadedConfig);
    
     //parse words list from config
    this.words = Arrays.asList(this.loadedConfig.getProperty("WORDS").split("\\s*,\\s*"));
  }

  public void setup() {
    System.out.println("MODE: Word");
  }

  public void draw() {
    if (this.pressCount == this.getIntProp("PRESSES_FOR_WORD_SWITCH")){    
      pressCount = 0;
      //cycle index
      if (++wordIndex >= words.size()){
        this.wordIndex = 0;
      }
    }
    
    stroke(0, 255, 0);    
    textSize(32);
    text(this.words.get(wordIndex), 100, 100);
  }
  
  public void handleMidi(byte[] raw, byte messageType, int channel, int note, int vel, int controllerNumber, int controllerVal, Pad pad){    
    //filter out unassigned notes and note_off messages
    if (pad != null && vel > 0){
      this.pressCount++;
    }
  }
}
