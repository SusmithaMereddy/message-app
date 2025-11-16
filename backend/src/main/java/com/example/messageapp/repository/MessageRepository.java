package com.example.messageapp.repository;

import com.example.messageapp.model.Message;
import org.springframework.data.mongodb.repository.MongoRepository;
import java.util.List;

public interface MessageRepository extends MongoRepository<Message, String> {
    List<Message> findTop10ByOrderByTimestampDesc();
}