package com.github.cldmnky.lolcat;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.*;

@QuarkusTest
public class LolcatResourceTest {

    @Test
    public void testLolcatEndpoint() {
        LolcatRequest request = new LolcatRequest("Hello World", 0.0, 3.0, 0.1);
        
        given()
          .contentType("application/json")
          .body(request)
          .when().post("/api/lolcat")
          .then()
             .statusCode(200)
             .body("original", equalTo("Hello World"))
             .body("colorized", notNullValue())
             .body("colorized", containsString("\u001b["));
    }

    @Test
    public void testLolcatWithMultiline() {
        LolcatRequest request = new LolcatRequest("Line 1\nLine 2\nLine 3", null, null, null);
        
        given()
          .contentType("application/json")
          .body(request)
          .when().post("/api/lolcat")
          .then()
             .statusCode(200)
             .body("colorized", containsString("\n"));
    }
}
