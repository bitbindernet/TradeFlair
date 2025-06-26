CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `redditId` varchar(45) NOT NULL,
  `jsondata` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  UNIQUE KEY `redditId_UNIQUE` (`redditId`)
) ENGINE=InnoDB AUTO_INCREMENT=159 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

ALTER TABLE users ADD COLUMN tradeFlairOffset INT DEFAULT 0;
