package com.github.cldmnky.lolcat;

public class LolcatRequest {
    public String text;
    public Double seed;
    public Double spread;
    public Double freq;

    public LolcatRequest() {
    }

    public LolcatRequest(String text, Double seed, Double spread, Double freq) {
        this.text = text;
        this.seed = seed;
        this.spread = spread;
        this.freq = freq;
    }
}
