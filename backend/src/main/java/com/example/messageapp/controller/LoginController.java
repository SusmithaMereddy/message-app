package com.example.messageapp.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api")
public class LoginController {

    // Pre-created credentials
    private static final Map<String, String> USERS = Map.of(
        "Administrator", "Pwd&1234",
        "Super admin", "Pwd&1234",
        "User A", "Pwd&1234",
        "User B", "Pwd&1234"
    );

    @PostMapping("/login")
    public ResponseEntity<String> login(@RequestBody Map<String, String> credentials) {
        String username = credentials.get("username");
        String password = credentials.get("password");

        if (USERS.containsKey(username) && USERS.get(username).equals(password)) {
            return ResponseEntity.ok("Login Successful");
        } else {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid credentials");
        }
    }
}