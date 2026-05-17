#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "DatabaseManager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    DatabaseManager dbManager;
    if (!dbManager.initDatabase()) {
        qWarning("Failed to initialize database!");
    }
    engine.rootContext()->setContextProperty("dbManager", &dbManager);

    engine.loadFromModule("dddd", "Main");

    return QCoreApplication::exec();
}
