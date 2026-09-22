import pandas as pd
import json
import ast


class DisplayElements:
    ROBOT_LIBRARY_SCOPE = 'TEST CASE'

    def __init__(self, path_to_excel):
        self.excel_path = path_to_excel
        print(f"*INFO* {self.excel_path=}")

    def totalRows(self, sheetName):
        df = pd.read_excel(self.excel_path,sheet_name=sheetName)
        return(len(df))

    def getRow(self, columnName,objectName,sheetName):
        print(columnName,objectName,sheetName)
    # Read the excel file into a pandas DataFrame
        df = pd.read_excel(self.excel_path,sheet_name=sheetName)

    # Search for rows where any column contains 'value'
        result = df[df[columnName]==objectName]
        if result.empty:
            raise AssertionError(objectName+' Not Found in DataSheet')
        return(result.to_dict(orient='list'))

    def getRows(self, columnName,objectName,sheetName):
        print(columnName,objectName,sheetName)
    # Read the excel file into a pandas DataFrame
        df = pd.read_excel(self.excel_path,sheet_name=sheetName,)

    # Search for rows where any column contains 'value'
        result = df[df[columnName]==objectName]
        if result.empty:
            raise AssertionError(objectName+' Not Found in DataSheet')
        return(result.to_dict(orient='records'))

    def getPanelRows(self, screenColumnName,screenName,panelColumnName,objectName,sheetName):
        print(screenColumnName,screenName,panelColumnName,objectName,sheetName)
    # Read the excel file into a pandas DataFrame
        df = pd.read_excel(self.excel_path,sheet_name=sheetName)

    # Search for rows where any column contains 'value'
        result = df[(df[screenColumnName]==screenName) & (df[panelColumnName]==objectName)]
        if result.empty:
            raise AssertionError(objectName+' Not Found in DataSheet')
        return(result.to_dict(orient='list'))


    def getScreenPanelRow(self, screenName,panelName,sheetName):

    # Read the excel file into a pandas DataFrame
        df = pd.read_excel(self.excel_path,sheet_name=sheetName)

    # Search for rows where any column contains 'value'
        result = df[(df['screenName']==screenName) & (df['panelName']==panelName)]
        if result.empty:
            raise AssertionError(panelName+' Not Found in DataSheet')
        return(result.to_dict(orient='records'))


    def getScreenRow(self, screenName,sheetName):

        # Read the excel file into a pandas DataFrame
        df = pd.read_excel(self.excel_path, sheet_name=sheetName)

        # Search for rows where any column contains 'value'
        result = df[(df['screenName']==screenName)]
        if result.empty:
            raise AssertionError(screenName+' Not Found in DataSheet')
        return(result.to_dict(orient='records'))




    def writeResult(self, result):
        # df = pd.DataFrame(result)

        print(result)
        df = pd.DataFrame(result)
        print(df)
        with pd.ExcelWriter(self.excel_path, mode='a',if_sheet_exists='new') as writer:
            df.to_excel(writer,index=False)



        # for screen in df.values:
        #     # print(screen)
        #     tmp = pd.DataFrame(screen)
        #     tmp.



            # df[screen] = df[screen].apply(string_to_dict)
            # print(df[screen])



    def string_to_dict(self, string_list):
        try:
            return ast.literal_eval(string_list)
        except (SyntaxError, ValueError):
            return None

