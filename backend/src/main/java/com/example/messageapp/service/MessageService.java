package com.example.messageapp.service; // Make sure this line is correct

import com.example.messageapp.model.Message;
import com.example.messageapp.repository.MessageRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.time.Instant; 

@Service
public class MessageService { 

    @Autowired
    private MessageRepository messageRepository;

    private static final DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd:MM:yyyy HH:mm:ss");


    public Message saveMessage(String content) {
        Message message = new Message();
        message.setContent(content);
        message.setTimestamp(Instant.now());
        return messageRepository.save(message);
    }

    public List<Message> getLatest10Messages() {
        return messageRepository.findTop10ByOrderByTimestampDesc();
    }
}