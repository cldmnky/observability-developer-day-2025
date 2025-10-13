package com.github.cldmnky.lolcat;

public class LolcatColorizer {
    
    /**
     * Applies rainbow lolcat coloring to text using ANSI escape codes
     * 
     * @param text The text to colorize
     * @param seed Starting position in the rainbow (0.0-1.0)
     * @param spread Color spread factor (higher = more gradual transitions)
     * @param freq Frequency of color oscillation
     * @return Text with ANSI color codes
     */
    public static String colorize(String text, double seed, double spread, double freq) {
        StringBuilder result = new StringBuilder();
        String[] lines = text.split("\n", -1);
        
        int charIndex = 0;
        for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
            String line = lines[lineIndex];
            
            for (int i = 0; i < line.length(); i++) {
                char ch = line.charAt(i);
                
                // Don't colorize whitespace, just append it
                if (Character.isWhitespace(ch)) {
                    result.append(ch);
                    continue;
                }
                
                // Calculate rainbow color based on character position
                double position = seed + (charIndex / spread);
                int red = (int) (Math.sin(freq * position) * 127 + 128);
                int green = (int) (Math.sin(freq * position + 2 * Math.PI / 3) * 127 + 128);
                int blue = (int) (Math.sin(freq * position + 4 * Math.PI / 3) * 127 + 128);
                
                // Clamp values to 0-255
                red = Math.max(0, Math.min(255, red));
                green = Math.max(0, Math.min(255, green));
                blue = Math.max(0, Math.min(255, blue));
                
                // Apply ANSI 24-bit true color
                result.append(String.format("\u001b[38;2;%d;%d;%dm%c\u001b[0m", red, green, blue, ch));
                charIndex++;
            }
            
            // Add newline except for last line
            if (lineIndex < lines.length - 1) {
                result.append('\n');
            }
        }
        
        return result.toString();
    }
}
