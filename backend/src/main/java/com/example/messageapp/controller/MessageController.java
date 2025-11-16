package com.example.messageapp.controller;

import com.example.messageapp.model.Message;
import com.example.messageapp.service.MessageService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class MessageController {

    @Autowired
    private MessageService messageService;

    @PostMapping("/messages")
    public ResponseEntity<Message> createMessage(@RequestBody Map<String, String> payload) {
        String content = payload.get("content");
        if (content == null || content.trim().isEmpty() || content.length() > 250) {
            return ResponseEntity.badRequest().build();
        }
        Message savedMessage = messageService.saveMessage(content);
        return ResponseEntity.ok(savedMessage);
    }

    @GetMapping("/messages")
    public ResponseEntity<List<Message>> getMessages() {
        return ResponseEntity.ok(messageService.getLatest10Messages());
    }
}