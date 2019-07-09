import java.util.Map;
import java.util.HashMap; 

public class Pad {
  static int lastIndex = 0; 
  public String name;
  public int index;
  public int note;
  public boolean isAux;

  private static Map<Integer, Integer> noteToPadMap = new HashMap();

  public static int noteToPad(int note) {
    int toReturn = -1;
    if (noteToPadMap.containsKey(note)) {
      toReturn = noteToPadMap.get(note);
    }
    return toReturn;
  }

  public Pad(String name, int note, boolean isAux) {
    this.name = name;
    this.note = note;
    this.index = lastIndex++;
    this.isAux = isAux;
    noteToPadMap.put(note, this.index);
  }
}
