CREATE TABLE `flair` (
  `id` int NOT NULL AUTO_INCREMENT,
  `flaircol` varchar(255) DEFAULT NULL,
  `updated` datetime DEFAULT NULL,
  `userid` int NOT NULL,
  `trade_count` int DEFAULT '0',
  `emojis` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  UNIQUE KEY `userid_UNIQUE` (`userid`),
  UNIQUE KEY `uniq_user_subreddit` (`userid`),
  CONSTRAINT `fk_flair_userid` FOREIGN KEY (`userid`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB AUTO_INCREMENT=2162 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
