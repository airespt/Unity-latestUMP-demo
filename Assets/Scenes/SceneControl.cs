using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Video;
using NaughtyAttributes;
using UMP;

public class SceneControl : MonoBehaviour
{
  [ReorderableList]
  public List<VideoSrc> videoSources;

  [Space]
  public UniversalMediaPlayer player;
  public Text activeUrl; 

  private bool visible = true;

  public void onClick_RenderTarget() {
    visible = !visible;
  }


  void OnGUI() {
    if( visible ) {
      var h = Screen.height / 15;
      GUI.skin.button.fontSize = h/2;

      for(int i = 0; i < videoSources.Count; i++) {
        if( GUI.Button(new Rect(50, h*(i+1), 600, h*0.8f), videoSources[i].name) ) {
          //player.Stop();
          activeUrl.text = videoSources[i].url;
          player.Path = videoSources[i].url;
          player.Play();
        }
      }
    }
  }
}

[Serializable]
public class VideoSrc {
  public string name;
  public string url;
}

// https://milage.ualg.pt/fmvg/get_poi_resource?id_poi=490&resource_number=5785&language=&application_name=LOST
// https://milage.ualg.pt/fmvg/get_poi_resource?id_poi=490&resource_number=5899&language=&application_name=LOST
// https://milage.ualg.pt/fmvg/get_poi_resource?id_poi=532&resource_number=5881&language=&application_name=LOST
// https://milage.ualg.pt/fmvg/get_poi_resource?id_poi=532&resource_number=5935&language=&application_name=LOST