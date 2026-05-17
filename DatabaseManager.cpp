#include "DatabaseManager.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

DatabaseManager::DatabaseManager(QObject *parent) : QObject(parent)
{
}

DatabaseManager::~DatabaseManager()
{
    if (m_db.isOpen()) {
        m_db.close();
    }
}

bool DatabaseManager::initDatabase()
{
    QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(dataDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    
    QString dbPath = dataDir + "/budget.sqlite";
    m_db = QSqlDatabase::addDatabase("QSQLITE");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qWarning() << "Could not open database:" << m_db.lastError().text();
        return false;
    }

    QSqlQuery query;
    // Create incomes table
    if (!query.exec("CREATE TABLE IF NOT EXISTS incomes ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "amount REAL, "
                    "date TEXT)")) {
        qWarning() << "Failed to create incomes table:" << query.lastError().text();
    }

    // Create expenses table
    if (!query.exec("CREATE TABLE IF NOT EXISTS expenses ("
                    "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                    "category TEXT, "
                    "name TEXT, "
                    "amount REAL, "
                    "date TEXT, "
                    "color TEXT, "
                    "subitems TEXT)")) {
        qWarning() << "Failed to create expenses table:" << query.lastError().text();
    } else {
        // Try to add column if table already existed without it
        query.exec("ALTER TABLE expenses ADD COLUMN subitems TEXT");
    }

    return true;
}

bool DatabaseManager::addIncome(double amount, const QString &date)
{
    QSqlQuery query;
    query.prepare("INSERT INTO incomes (amount, date) VALUES (:amount, :date)");
    query.bindValue(":amount", amount);
    query.bindValue(":date", date);
    return query.exec();
}

double DatabaseManager::getTotalIncome(const QString &startDate, const QString &endDate)
{
    QSqlQuery query;
    query.prepare("SELECT SUM(amount) FROM incomes WHERE date >= :start AND date <= :end");
    query.bindValue(":start", startDate);
    query.bindValue(":end", endDate);
    query.exec();
    if (query.next()) {
        return query.value(0).toDouble();
    }
    return 0.0;
}

bool DatabaseManager::addExpense(const QString &category, const QString &name, double amount, const QString &date, const QString &color, const QString &subitems)
{
    QSqlQuery query;
    query.prepare("INSERT INTO expenses (category, name, amount, date, color, subitems) "
                  "VALUES (:category, :name, :amount, :date, :color, :subitems)");
    query.bindValue(":category", category);
    query.bindValue(":name", name);
    query.bindValue(":amount", amount);
    query.bindValue(":date", date);
    query.bindValue(":color", color);
    query.bindValue(":subitems", subitems);
    return query.exec();
}

bool DatabaseManager::updateExpense(int id, const QString &category, const QString &name, double amount, const QString &color, const QString &subitems)
{
    QSqlQuery query;
    query.prepare("UPDATE expenses SET category = :category, name = :name, amount = :amount, color = :color, subitems = :subitems WHERE id = :id");
    query.bindValue(":category", category);
    query.bindValue(":name", name);
    query.bindValue(":amount", amount);
    query.bindValue(":color", color);
    query.bindValue(":subitems", subitems);
    query.bindValue(":id", id);
    return query.exec();
}

bool DatabaseManager::deleteExpense(int id)
{
    QSqlQuery query;
    query.prepare("DELETE FROM expenses WHERE id = :id");
    query.bindValue(":id", id);
    return query.exec();
}

QVariantList DatabaseManager::getGroupedExpenses()
{
    QVariantList groupedList;
    
    // First get unique categories
    QSqlQuery catQuery("SELECT DISTINCT category, color FROM expenses");
    while (catQuery.next()) {
        QString cat = catQuery.value(0).toString();
        QString color = catQuery.value(1).toString();
        
        QVariantMap categoryMap;
        categoryMap["category"] = cat;
        categoryMap["color"] = color;
        
        // Get total for this category
        QSqlQuery sumQuery;
        sumQuery.prepare("SELECT SUM(amount) FROM expenses WHERE category = :cat");
        sumQuery.bindValue(":cat", cat);
        sumQuery.exec();
        double catTotal = 0;
        if (sumQuery.next()) {
            catTotal = sumQuery.value(0).toDouble();
        }
        categoryMap["totalAmount"] = catTotal;
        
        // Get items for this category
        QVariantList items;
        QSqlQuery itemQuery;
        itemQuery.prepare("SELECT id, name, amount, date FROM expenses WHERE category = :cat ORDER BY id DESC");
        itemQuery.bindValue(":cat", cat);
        itemQuery.exec();
        
        while (itemQuery.next()) {
            QVariantMap item;
            item["id"] = itemQuery.value(0).toInt();
            item["name"] = itemQuery.value(1).toString();
            item["amount"] = itemQuery.value(2).toDouble();
            item["date"] = itemQuery.value(3).toString();
            items.append(item);
        }
        
        categoryMap["items"] = items;
        groupedList.append(categoryMap);
    }
    
    return groupedList;
}

QVariantList DatabaseManager::getExpenses(const QString &startDate, const QString &endDate)
{
    QVariantList list;
    QSqlQuery query;
    query.prepare("SELECT id, category, name, amount, date, color, subitems FROM expenses WHERE date >= :start AND date <= :end ORDER BY date DESC, id DESC");
    query.bindValue(":start", startDate);
    query.bindValue(":end", endDate);
    query.exec();
    while (query.next()) {
        QVariantMap item;
        item["id"] = query.value(0).toInt();
        item["category"] = query.value(1).toString();
        item["name"] = query.value(2).toString();
        item["amount"] = query.value(3).toDouble();
        item["date"] = query.value(4).toString();
        item["color"] = query.value(5).toString();
        item["subitems"] = query.value(6).toString();
        list.append(item);
    }
    return list;
}

QVariantList DatabaseManager::getCategorySummary(const QString &startDate, const QString &endDate)
{
    QVariantList summary;
    QSqlQuery query;
    query.prepare("SELECT category, color, SUM(amount) FROM expenses WHERE date >= :start AND date <= :end GROUP BY category");
    query.bindValue(":start", startDate);
    query.bindValue(":end", endDate);
    query.exec();
    while (query.next()) {
        QVariantMap map;
        map["name"] = query.value(0).toString();
        map["color"] = query.value(1).toString();
        map["amount"] = query.value(2).toDouble();
        summary.append(map);
    }
    return summary;
}

double DatabaseManager::getTotalExpenses(const QString &startDate, const QString &endDate)
{
    QSqlQuery query;
    query.prepare("SELECT SUM(amount) FROM expenses WHERE date >= :start AND date <= :end");
    query.bindValue(":start", startDate);
    query.bindValue(":end", endDate);
    query.exec();
    if (query.next()) {
        return query.value(0).toDouble();
    }
    return 0.0;
}

void DatabaseManager::clearDatabase()
{
    QSqlQuery query;
    query.exec("DELETE FROM incomes");
    query.exec("DELETE FROM expenses");
}
