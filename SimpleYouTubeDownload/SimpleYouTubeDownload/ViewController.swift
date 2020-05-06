//
//  ViewController.swift
//  SimpleYouTubeDownload
//
//  Created by Tom on 2020/05/06.
//  Copyright © 2020 Tom. All rights reserved.
//

import Cocoa


class ViewController: NSViewController {

    var downloadLocation:URL? = nil
    
    let urlField = NSTextField()
    let titleLabel = NSTextField()
    let statusLabel = NSTextField()
    let startButton = NSButton()
    let setDestinationButton = NSButton()
    var srtOn = NSButton()
    var waiting = [String]()
    var failed = [String]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(urlField)
        view.addSubview(startButton)
        view.addSubview(setDestinationButton)
        view.addSubview(titleLabel)
        view.addSubview(statusLabel)

        startButton.title = "Start"
        setDestinationButton.title = "Location"
        startButton.action = #selector(self.startButtonAction)
        setDestinationButton.action = #selector(self.setDestinationButtonAction)
        statusLabel.isEnabled = false
        titleLabel.isEnabled = false

         srtOn = NSButton.init(checkboxWithTitle:"Captions", target: self, action: #selector(self.changeSRT))
        view.addSubview(srtOn)

        srtOn.state = .off
        layout()
    }

    func layout() {
        let frame = self.view.frame
        urlField.frame.size.width = frame.size.width - 20
        urlField.frame.size.height = 30
        urlField.frame.origin.x = 10
        urlField.frame.origin.y = frame.size.height - 40
        
        startButton.frame.size.width = 60
        startButton.frame.size.height = 27
        startButton.frame.origin.x = frame.size.width - 70
        startButton.frame.origin.y = frame.size.height - 73
        
        setDestinationButton.frame = startButton.frame
        setDestinationButton.frame.origin.x = frame.size.width - 130
        
        srtOn.frame = setDestinationButton.frame
        srtOn.frame.origin.y -= srtOn.frame.size.height
        srtOn.frame.size.width += startButton.frame.size.width
            
        statusLabel.frame = urlField.frame
        statusLabel.frame.size.height = urlField.frame.origin.y - 10
        statusLabel.frame.origin.y = 5
        statusLabel.frame.size.width = setDestinationButton.frame.origin.x - statusLabel.frame.origin.x - 5
        statusLabel.frame.size.height /= 2
        titleLabel.frame = statusLabel.frame
        titleLabel.frame.origin.y += statusLabel.frame.size.height
    }

    func chooseFolder() -> URL? {
        let dialog = NSOpenPanel()
        
        dialog.title = "Choose Folder"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = true
        dialog.canCreateDirectories = true
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["xxxxxx"]
        
        if dialog.runModal() == NSApplication.ModalResponse.OK {
            let result = dialog.url
            
            if result != nil {
                return result
            }
        }
        return nil
    }
    @objc func changeSRT() {
        
    }
    @objc func setDestinationButtonAction() {
        if let url = chooseFolder() {
            downloadLocation = url
        }
    }
    @objc func startButtonAction() {
        if downloadLocation == nil {
            setDestinationButtonAction()
        }
        if downloadLocation != nil {
            let string = urlField.stringValue
            download(string)
        }
    }
    
    func done(_ success:Bool) {
        urlField.stringValue = ""
        if waiting.count > 0 {
            let string = waiting[0]
            waiting.remove(at:0)
            download(string)
        } else {
            if success {
                statusLabel.stringValue = "Completed Successfully"
            } else {
                statusLabel.stringValue = "Done (\(failed.count) failed)"
            }
            waiting = []
            failed = []
        }
    }
    
    
    func fixURLString(_ string:String) -> String {
        return string.replacingOccurrences(of:"https://www.youtube.com/watch?v=", with:"").replacingOccurrences(of:"http://www.youtube.com/watch?v=", with:"").replacingOccurrences(of:"https://youtu.be/", with:"").replacingOccurrences(of:"http://youtu.be/", with:"")
    }
    
    
    func download(_ watchString:String) {
        let string = fixURLString(watchString)
        extractVideos(from:string) { (dic) -> (Void) in
            if let titleString = dic["title"], let urlString = (dic["url"]), let url = URL(string:urlString) {
                DispatchQueue.main.async {
                    if self.srtOn.state == .on {
                        self.extractCaptions(from:string) { (lang,caption) -> (Void) in
                            let filename = "\(titleString).\(lang).srt"
                            if let downLocation = self.downloadLocation {
                                let captionSaveURL = downLocation.appendingPathComponent(
                                    filename)
                                DispatchQueue.main.async {
                                    do {
                                        try caption.write(to: captionSaveURL, atomically: true, encoding: String.Encoding.utf8)
                                    } catch {
                                    }
                                }
                            }
                        }
                    }
                    if self.activeDownloads.count > 0 {
                        self.waiting += [string]
                    } else {
                        self.startDownload(url, title:titleString)
                    }
                    self.urlField.stringValue = ""
                }
            } else {
                DispatchQueue.main.async {
                    self.failed += [string]
                    self.done(false)
                }
            }
        }
    }
    
    func startDownload(_ url:URL, title:String) {
        let download = Download(url: url)
        download.task = URLSession.shared.downloadTask(with: url) { location, response, error in

            self.downloadTimer.invalidate()
            self.activeDownloads[url] = nil
            let filename = "\(title).mp4"
            if let locationURL = location {
                if let downLocation = self.downloadLocation {
                    let saveURL = downLocation.appendingPathComponent(
                        filename)
                    try? FileManager.default.moveItem(at: locationURL, to: saveURL); do { }
                }
            }
            DispatchQueue.main.async {
                self.activeDownloads[url] = nil
                self.done(true)
            }
        }
        download.task!.resume()
        download.isDownloading = true
        download.title = title
        activeDownloads[download.url] = download
        
        downloadTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.downloadTimerAction(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(downloadTimer, forMode:RunLoop.Mode.common)
    }
    
    var activeDownloads: [URL: Download] = [:]
    final class Download: NSObject {

      var url: URL
        var title: String = ""
      var isDownloading = false
      var progress: Float = 0
      var task: URLSessionDownloadTask?
      var resumeData: Data?

      init(url: URL) {
        self.url = url
      }
    }
    
    var downloadTimer = Timer()
    @objc func downloadTimerAction(_ timer:Timer) {
        for download in activeDownloads.values {
            if let task = download.task {
                let completed = task.countOfBytesReceived
                let total = task.countOfBytesExpectedToReceive
                if total == 0 {return}
                let progress = Float(1000 * completed / total) / 10
                titleLabel.stringValue = download.title
                var string = "Downloading \(progress)%"
                if waiting.count > 0 {
                    string += " (\(waiting.count)waiting)"
                }
                statusLabel.stringValue = string
            }
        }
    }
    
    func extractVideos(from youtubeId : String, completion: @escaping (([String:String]) -> (Void)))
    {

        let strUrl = "http://www.youtube.com/get_video_info?video_id=\(youtubeId)"//&el=embedded&ps=default&eurl=&gl=US&hl=en"
        let url = URL(string: strUrl)!
        
        URLSession.shared.dataTask(with: url) { (datatmp, response, error) in
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    self.failed += [youtubeId]
                    self.done(false)
                }
                return
            }
            guard (response as? HTTPURLResponse) != nil else {
                print(response as Any)
                DispatchQueue.main.async {
                    self.failed += [youtubeId]
                    self.done(false)
                }
                return
            }
            
            if let data = datatmp,
                let string = String(data: data, encoding: .utf8), let response = string.removingPercentEncoding {
                let dic = self.getDictionnaryFrom(string: response)
                completion(dic)
            }
            }.resume()
    }
    
    func getDictionnaryFrom(string: String) -> [String:String] {
        var dic = [String:String]()
        let result = string.replacingOccurrences(of:"\\u0026", with:"&")
        let parts = result.components(separatedBy: ",")
        
        var urlString:String? = nil
        var firstURLString:String? = nil

        for part in parts{
            let keyval = part.components(separatedBy: "\":\"")
            
            if (keyval.count == 2){
                if dic["url"] == nil && keyval[0] == "\"url" {
                    urlString = keyval[1].replacingOccurrences(of:"\"", with:"")
                    if firstURLString == nil {
                        firstURLString = urlString
                    }
                }
                
                if keyval[0] == "\"quality" && keyval[1] == "medium\"" {
                    if let string = urlString {
                        if dic["url"] == nil {
                            dic["url"] = string
                        }
                    }
                }
                if keyval[0] == "\"title" {
                    dic["title"] = keyval[1].replacingOccurrences(of:"\"", with:"").replacingOccurrences(of: "+", with:" ")
                }
            }
        }
        if dic["url"] == nil {
            if let string = firstURLString {
                dic["url"] = string
            }
        }
        return dic
    }
    
    
    //MARK: - Caption
    func extractCaptions(from youtubeId : String, completion: @escaping ((_ lang:String, _ caption:String) -> (Void)))
    {
        let strUrl = "https://video.google.com/timedtext?type=list&v=\(youtubeId)"
        let url = URL(string: strUrl)!
        
        URLSession.shared.dataTask(with: url) { (datatmp, response, error) in
            if let error = error {
                print(error.localizedDescription)
            }
            guard (response as? HTTPURLResponse) != nil else {
                print(response as Any)
                return
            }
            if let data = datatmp,
                let string = String(data: data, encoding: .utf8), let response = string.removingPercentEncoding {
                print(string)
                let dic = self.getCaptionListDictionnaryFrom(string: response, youtubeId:youtubeId)
                self.extractCaptions(dic, completion:completion)
            }
            }.resume()
    }
    
    func extractCaptions(_ dic:[String:URL], completion: @escaping ((_ lang:String, _ caption:String) -> (Void))) {
        for lang in dic {
            let url:URL = lang.value
            let langString = lang.key
            URLSession.shared.dataTask(with: url) { (datatmp, response, error) in
                if let error = error {
                    print(error.localizedDescription)
                }
                guard (response as? HTTPURLResponse) != nil else {
                    print(response as Any)
                    return
                }
                if let data = datatmp,
                    let string = String(data: data, encoding: .utf8), let _ = string.removingPercentEncoding {
                    completion(langString,self.generateCaptionSRTfromXML(string))
                }
            }.resume()
        }
    }
    
    func getCaptionListDictionnaryFrom(string: String, youtubeId:String) -> [String:URL] {
        var dic = [String:URL]()
        let parts = string.components(separatedBy: "<track id=\"")
        for part in parts {
            var name = ""
            let partsForName = part.components(separatedBy: "name=\"")
            if partsForName.count == 2 {
                let partForName = partsForName[1]
                let partsForName2 = partForName.components(separatedBy: "\"")
                if partsForName2.count > 1 {
                    name = partsForName2[0]
                }
            }
            var lang = ""
            let partsForLang = part.components(separatedBy: " lang_code=\"")
            if partsForLang.count == 2 {
                let partForLang = partsForLang[1]
                let partsForLang2 = partForLang.components(separatedBy: "\"")
                if partsForLang2.count > 1 {
                    lang = partsForLang2[0]
                    //dic[lang] = name
                    let strUrl = "https://video.google.com/timedtext?type=track&v=\(youtubeId)&name=\(name)&lang=\(lang)"
                    let url = URL(string: strUrl)!
                    dic[lang] = url
                }
            }
        }
        return dic
    }
    
    func generateCaptionSRTfromXML(_ getString:String) -> String {
        var result = ""
        let captions = getString.components(separatedBy: "<text start=\"")
        var captionNumber = 0
        for captionProperties in captions {
            let propertiesArray = captionProperties.components(separatedBy: "\" dur=\"")
            if propertiesArray.count > 1 {
                let startString = propertiesArray[0]
                let properties = propertiesArray[1]
                let propertiesArray2 = properties.components(separatedBy: "\">")
                if propertiesArray2.count > 1 {
                    let durationString = propertiesArray2[0]
                    let caption = propertiesArray2[1].replacingOccurrences(of:"</text>", with:"").replacingOccurrences(of:"</transcript>", with:"").replacingOccurrences(of:"&amp;#39;", with:"'").replacingOccurrences(of:"&amp;quot;", with:"\"")
                    print(" fixed: \(caption)")
                    if let start = Float(startString), let duration = Float(durationString) {
                        let end = start + duration
                        captionNumber += 1
                        let startTime = floatToTime(start)
                        let endTime = floatToTime(end)
                        
                        let startTimeString = String(format: "%02d:%02d:%02d,%03d", startTime.hour, startTime.min,startTime.sec,startTime.msec3)
                        let endTimeString = String(format: "%02d:%02d:%02d,%03d", endTime.hour, endTime.min,endTime.sec,endTime.msec3)
                        
                        result += "\(captionNumber)\n\(startTimeString) --> \(endTimeString)\n\(caption)\n\n"
                    }
                }
            }
        }
        return result
    }
    func floatToTime(_ floatValue:Float) -> (hour:Int, min:Int, sec:Int, msec3:Int) {
        let wholeSecond = Int(floatValue)
        let hour = Int(wholeSecond / 3600)
        let minute = Int(wholeSecond / 60) - (hour * 60)
        let second = wholeSecond - (hour * 3600) - (minute * 60)
        let miliSecond = Int((floatValue - Float(wholeSecond)) * 1000)
        return (hour, minute, second, miliSecond)
    }
}



