package com.example.messageapp.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.annotation.CreatedDate;
import java.time.Instant;
import lombok.Data;

@Data
@Document(collection = "messages")
public class Message {
    @Id
    private String id;
    private String content;
    @CreatedDate
    private Instant timestamp;
}
