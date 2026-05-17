#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>

class DatabaseManager : public QObject
{
    Q_OBJECT
public:
    explicit DatabaseManager(QObject *parent = nullptr);
    ~DatabaseManager();

    Q_INVOKABLE bool initDatabase();

    // Income
    Q_INVOKABLE bool addIncome(double amount, const QString &date);
    Q_INVOKABLE double getTotalIncome(const QString &startDate, const QString &endDate);

    // Expenses
    Q_INVOKABLE bool addExpense(const QString &category, const QString &name, double amount, const QString &date, const QString &color, const QString &subitems);
    Q_INVOKABLE bool updateExpense(int id, const QString &category, const QString &name, double amount, const QString &color, const QString &subitems);
    Q_INVOKABLE bool deleteExpense(int id);
    
    // Grouped by Category for Accordion List
    Q_INVOKABLE QVariantList getGroupedExpenses();

    // All flat expenses within range
    Q_INVOKABLE QVariantList getExpenses(const QString &startDate, const QString &endDate);

    // Aggregated for Ring Chart within range
    Q_INVOKABLE QVariantList getCategorySummary(const QString &startDate, const QString &endDate);
    
    // Total Expenses within range
    Q_INVOKABLE double getTotalExpenses(const QString &startDate, const QString &endDate);

    // Utilities
    Q_INVOKABLE void clearDatabase();

private:
    QSqlDatabase m_db;
};
