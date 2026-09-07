package game

import (
	"time"
)

// Игровая карточка
type GameCard struct {
	ID      int    `json:"id" gorm:"primaryKey;autoIncrement"`
	Title   string `json:"title"`
	IconUrl string `json:"iconUrl"`
	GameId  int    `json:"gameId" gorm:"unique"`
}

// Подробная информация об игре
type GameInfo struct {
	ID               int             `json:"id" gorm:"primaryKey;autoIncrement"`
	Title            string          `json:"title"`
	IconUrl          string          `json:"iconUrl"`
	SteamAppID       int64           `json:"steamAppId" gorm:"index"`
	SteamDeckCommand string          `json:"steamDeckCommand"`
	TranslateCards   []TranslateCard `json:"translateCards" gorm:"foreignKey:GameInfoID"`
}

// Инфонрмация о переводе
type TranslateCard struct {
	ID            int                 `json:"id" gorm:"primaryKey;autoIncrement"`
	AuthorName    string              `json:"authorName"`
	AuthorId      int                 `json:"authoreId"`
	Source        string              `json:"source"`
	Version       float64             `json:"version"`
	PercentReady  float64             `json:"percentReady"`
	UrlToDownload string              `json:"urlToDownload"`
	ArchiveHash   string              `json:"archiveHash" gorm:"index"`
	FileSize      float64             `json:"fileSize"`
	Status        string              `json:"status" gorm:"default:pending"` //pending, approved, rejected, error
	ScanDetails   string              `json:"scanDetails" gorm:"default:''"`
	GameFiles     []DetailedGameFiles `json:"gameFiles" gorm:"serializer:json"`
	GameInfoID    int                 `json:"-"`
	CreatedAt     time.Time           `json:"createdAt"`
}

// Информация о файле, находящимся в переводе
type DetailedGameFiles struct {
	FileName string `json:"fileName" binding:"required"`
	Hash     string `json:"hash" binding:"required"`
	Size     string `json:"size" binding:"required"`
}

type CreateGameRequest struct {
	Title            string `form:"Title" binding:"required"`
	SteamAppID       int64  `form:"steamAppId"`
	SteamDeckCommand string `form:"steamDeckCommand"`
}

type CreateTraslateRequest struct {
	AuthorName   string  `json:"authorName"`
	Source       string  `json:"source"`
	Version      float64 `json:"version"`
	PercentReady float64 `json:"percentReady"`
}

type SteamGameInfo struct {
	Title string `json:"title"`
	ID    int64  `json:"id"`
}

type SteamGameCache struct {
	ID             int    `json:"id" gorm:"primaryKey;autoIncrement"`
	QueryTitle     string `json:"queryTitle" gorm:"not null"`
	QueryTitleHash string `json:"queryTitleHash" gorm:"uniqueIndex;not null"`
	SteamTitle     string `json:"steamTitle" gorm:"not null"`
	SteamAppID     int64  `json:"steamAppId" gorm:"not null"`
	CreatedAt      time.Time
	UpdatedAt      time.Time
}
