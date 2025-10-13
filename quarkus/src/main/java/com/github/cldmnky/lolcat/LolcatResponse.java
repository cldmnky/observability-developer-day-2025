package com.github.cldmnky.lolcat;

public class LolcatResponse {
    public String original;
    public String colorized;

    public LolcatResponse() {
    }

    public LolcatResponse(String original, String colorized) {
        this.original = original;
        this.colorized = colorized;
    }
}
