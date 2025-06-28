CREATE TABLE `tradethreads` (
  `id` int NOT NULL AUTO_INCREMENT,
  `redditId` varchar(20) NOT NULL,
  `subreddit` varchar(100) NOT NULL,
  `url` text NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `json` json DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `redditId_UNIQUE` (`redditId`),
  KEY `ix_subreddit` (`subreddit`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
