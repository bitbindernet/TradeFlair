CREATE TABLE `messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `json` json DEFAULT NULL,
  `redditId` varchar(45) DEFAULT NULL,
  `redditParentId` varchar(45) DEFAULT NULL,
  `body` longtext,
  `created` datetime DEFAULT NULL,
  `tradeThreadId` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  UNIQUE KEY `redditId_UNIQUE` (`redditId`),
  KEY `ix_created` (`created`),
  KEY `fk_messages_thread` (`tradeThreadId`),
  CONSTRAINT `fk_messages_thread` FOREIGN KEY (`tradeThreadId`) REFERENCES `tradethreads` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=159 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE messages
  ADD INDEX idx_tradeThreadId   (tradeThreadId),
  ADD INDEX idx_redditId        (redditId),
  ADD INDEX idx_redditParentId  (redditParentId),
  ADD FULLTEXT INDEX ft_body (body);